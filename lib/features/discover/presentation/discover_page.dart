import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:gamecollect/features/discover/presentation/widgets/custom_lens_upload_view.dart';
import 'dart:io';

import '../../../core/theme/app_theme.dart';
import '../data/rawg_games_api.dart';
import '../domain/rawg_game.dart';
import 'widgets/discover_search_bar.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const int _pageSize = 20;
  static const Duration _searchDebounce = Duration(milliseconds: 800);

  String get _rawgApiKey => dotenv.env['RAWG_API_KEY'] ?? '';

  bool get _showCameraButton {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final http.Client _httpClient = http.Client();
  final ImagePicker _imagePicker = ImagePicker();
  final RawgGamesApi _rawgGamesApi = const RawgGamesApi();

  Timer? _debounce;
  Timer? _slowConnectionTimer;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _isOpeningCamera = false;
  bool _isRecognizingCover = false;
  bool _isSlowConnection = false;
  String? _errorMessage;
  String _activeQuery = '';
  List<RawgGame> _games = const [];
  String? _nextPageUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchGames(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slowConnectionTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _httpClient.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    final shouldLoadMore =
        position.pixels >= (position.maxScrollExtent - 500) &&
        _nextPageUrl != null;

    if (shouldLoadMore) {
      _fetchGames(loadMore: true);
    }
  }

  Future<void> _fetchGames({bool reset = false, bool loadMore = false}) async {
    _slowConnectionTimer?.cancel();

    if (_rawgApiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'RAWG API key ontbreekt. Zet RAWG_API_KEY in je lokale .env file.';
        _games = const [];
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    if (loadMore && _nextPageUrl == null) {
      return;
    }

    setState(() {
      _isSlowConnection = false;
      if (reset) {
        _isInitialLoading = true;
        _errorMessage = null;
        _games = const [];
        _nextPageUrl = null;
      } else if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isInitialLoading = true;
        _errorMessage = null;
      }
    });

    _slowConnectionTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && (_isInitialLoading || _isLoadingMore)) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });

    try {
      final page = await _rawgGamesApi.fetchGames(
        client: _httpClient,
        apiKey: _rawgApiKey,
        pageSize: _pageSize,
        activeQuery: _activeQuery,
        nextPageUrl: loadMore ? _nextPageUrl : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final mergedGames = loadMore ? [..._games, ...page.games] : page.games;
        _games = _sortGamesByRelevance(mergedGames, _activeQuery);
        _nextPageUrl = page.nextPageUrl;

        // Succesvolle inlaadbeurt voltooid
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final isNetworkError =
          error is SocketException ||
          error is TimeoutException ||
          (error.toString().contains('SocketException') ||
              error.toString().contains('ClientException'));

      setState(() {
        if (!loadMore) {
          if (isNetworkError) {
            _errorMessage = 'Controleer je internetverbinding';
          } else {
            _errorMessage = 'Er is iets misgegaan.';
          }
          _games = const [];
          _isInitialLoading = false;
        } else {
          // Als we al games hadden (loadMore = true) en connectie valt weg,
          // laten we `_isLoadingMore` op `true` staan zodat de spinner onderaan blijf staan
          // en hij infinite laadt, conform de vereisten.
        }
      });

      if (loadMore) {
        // Probeer automatisch periodiek opnieuw totdat de verbinding weer hersteld is
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isLoadingMore) {
            _fetchGames(loadMore: true);
          }
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      final query = value.trim();

      // Keep API usage low: only search after pause and at least 2 chars.
      if (query.isNotEmpty && query.length < 2) {
        return;
      }

      if (query == _activeQuery) {
        return;
      }

      _activeQuery = query;
      _fetchGames(reset: true);
    });
  }

  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query == _activeQuery) {
      return;
    }

    _activeQuery = query;
    _fetchGames(reset: true);
  }

  void _clearSearch() {
    _debounce?.cancel();

    if (_searchController.text.isEmpty && _activeQuery.isEmpty) {
      return;
    }

    _searchController.clear();
    _activeQuery = '';
    _fetchGames(reset: true);
  }

  List<RawgGame> _sortGamesByRelevance(List<RawgGame> games, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return games;
    }

    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    final sorted = [...games];
    sorted.sort((a, b) {
      final scoreA = _scoreGameRelevance(a.title, normalizedQuery, queryTokens);
      final scoreB = _scoreGameRelevance(b.title, normalizedQuery, queryTokens);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return sorted;
  }

  String _normalizeSearchText(String value) {
    final lowercase = value.toLowerCase();
    final noSpecialChars = lowercase.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    return noSpecialChars.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _scoreGameRelevance(
    String title,
    String normalizedQuery,
    List<String> queryTokens,
  ) {
    final normalizedTitle = _normalizeSearchText(title);
    var score = 0;

    if (normalizedTitle == normalizedQuery) {
      score += 10000;
    }

    if (normalizedTitle.startsWith(normalizedQuery)) {
      score += 7000;
    }

    if (normalizedTitle.contains(normalizedQuery)) {
      score += 4500;
    }

    var matchedTokens = 0;
    for (final token in queryTokens) {
      if (normalizedTitle.contains(token)) {
        matchedTokens++;
      }
    }

    if (matchedTokens == queryTokens.length) {
      score += 3000;
    }

    score += matchedTokens * 220;
    score -= (queryTokens.length - matchedTokens) * 600;

    final lengthDiff = (normalizedTitle.length - normalizedQuery.length).abs();
    score += (300 - (lengthDiff * 8)).clamp(0, 300);

    return score;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _openCamera() async {
    if (_isOpeningCamera || _isRecognizingCover) {
      return;
    }

    setState(() {
      _isOpeningCamera = true;
    });

    XFile? photo;
    try {
      photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      _showSnackBar('Camera kon niet worden geopend.');
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningCamera = false;
        });
      }
    }

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      _isRecognizingCover = true;
    });

    final photoFile = File(photo.path);

    try {
      final CodeLensResult? result = await showDialog<CodeLensResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _CameraSearchDialog(photoFile: photoFile);
        },
      );

      if (!mounted) {
        return;
      }

      if (result == null ||
          result.title.isEmpty ||
          result.title == "ERROR_NO_RESULTS") {
        _showSnackBar('Er werden geen zoekresultaten gevonden.');
        return;
      }

      if (result.title == "ERROR_NOT_A_GAME") {
        _showSnackBar(
          'De foto lijkt niet op een game cover, probeer het opnieuw.',
        );
        return;
      }

      final query = result.title;

      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(
        offset: query.length,
      );

      _onSearchSubmitted(query);
      _showSnackBar('Gevonden: $query');
    } catch (_) {
      if (mounted) {
        _showSnackBar('Foto kon niet verwerkt worden. Probeer opnieuw.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizingCover = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Glass effect search bar area
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: AppTheme.glassLight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    DiscoverSearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      onClearPressed: _clearSearch,
                      showCameraButton: _showCameraButton,
                      onCameraPressed: _openCamera,
                      isCameraBusy: false,
                      isCameraDisabled: _isOpeningCamera || _isRecognizingCover,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          // Grid content with padding
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildContent(textTheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TextTheme textTheme) {
    if (_isInitialLoading && _games.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_isSlowConnection) ...[
              const SizedBox(height: 16),
              Text(
                'Dit duurt langer dan normaal...',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.black),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      final isNetworkError =
          _errorMessage == 'Controleer je internetverbinding';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNetworkError
                    ? LucideIcons.wifiOff
                    : LucideIcons.triangleAlert,
                size: 48,
                color: AppTheme.orange500,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: textTheme.bodyLarge?.copyWith(color: AppTheme.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _fetchGames(reset: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                ),
                child: const Text('Opnieuw proberen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_games.isEmpty) {
      return Center(
        child: Text('Geen games gevonden.', style: textTheme.bodyLarge),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _games.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _games.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final game = _games[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: AppTheme.orange50,
                child: game.coverUrl == null
                    ? const Icon(
                        LucideIcons.gamepad2,
                        size: 34,
                        color: AppTheme.black,
                      )
                    : Image.network(
                        game.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            LucideIcons.gamepad2,
                            size: 34,
                            color: AppTheme.black,
                          );
                        },
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.blackTransparent0,
                        AppTheme.blackTransparent40,
                        AppTheme.blackTransparent80,
                      ],
                    ),
                  ),
                  child: Text(
                    game.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CameraSearchDialog extends StatefulWidget {
  final File photoFile;

  const _CameraSearchDialog({required this.photoFile});

  @override
  State<_CameraSearchDialog> createState() => _CameraSearchDialogState();
}

class _CameraSearchDialogState extends State<_CameraSearchDialog> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNetworkError = false;

  bool _isSlow = false;
  Timer? _slowTimer;

  int _retryKey = 0;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSearch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isNetworkError = false;
      _isSlow = false;
      _retryKey++;
    });

    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading && !_hasError) {
        setState(() {
          _isSlow = true;
        });
      }
    });

    // Explicit internet check to fail fast for SocketException
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _handleError('NETWORK_ERROR');
      }
    } on SocketException catch (_) {
      _handleError('NETWORK_ERROR');
    } catch (_) {
      // Ignored, let webview handle other errors
    }
  }

  void _handleError(String code) {
    if (!mounted) return;
    _slowTimer?.cancel();
    setState(() {
      _isLoading = false;
      _hasError = true;
      _isNetworkError = code == 'NETWORK_ERROR';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _hasError ? _buildErrorView() : _buildLoadingView(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Stack(
      key: const ValueKey('loading'),
      alignment: Alignment.center,
      children: [
        // Hidden rendering of webview off-screen to prevent covering Flutter UI
        Positioned(
          left: -1000,
          top: -1000,
          child: SizedBox(
            height: 10,
            width: 10,
            child: CustomLensUploadView(
              key: ValueKey(_retryKey),
              imageFile: widget.photoFile,
              onResult: (res) {
                if (mounted) {
                  Navigator.of(context).pop(res);
                }
              },
              onError: _handleError,
            ),
          ),
        ),
        // App-native Loading UI
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.orange500),
              const SizedBox(height: 24),
              Text(
                'Zoeken via afbeelding...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isSlow) ...[
                const SizedBox(height: 8),
                Text(
                  'Dit duurt langer dan normaal...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.gray700),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isNetworkError ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
            size: 48,
            color: AppTheme.orange500,
          ),
          const SizedBox(height: 16),
          Text(
            _isNetworkError
                ? 'Er is een fout opgetreden tijdens het zoeken. Controleer je internetverbinding en probeer opnieuw.'
                : 'Er is een fout opgetreden tijdens het zoeken.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _startSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.orange500,
              side: const BorderSide(color: AppTheme.orange500),
            ),
            child: const Text('Opnieuw proberen'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
            child: const Text('Annuleren'),
          ),
        ],
      ),
    );
  }
}
