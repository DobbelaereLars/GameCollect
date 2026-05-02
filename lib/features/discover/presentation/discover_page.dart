import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:gamecollect/features/discover/presentation/widgets/custom_lens_upload_view.dart';

import '../../../core/theme/app_theme.dart';
import '../data/rawg_games_api.dart';
import '../domain/rawg_game.dart';
import 'game_detail_page.dart';
import 'widgets/discover_search_bar.dart';
import '../../../core/preferences/view_preferences.dart';

/// Ontdekken-pagina: zoekt en bladert door games via de RAWG API.
/// Ondersteunt tekstzoeken, camera-scan via Google Lens en aanpasbare rasterweergave.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  /// Stel in om de Ontdekken-tab te openen en direct naar een game te navigeren.
  /// De shell luistert om van tab te wisselen; DiscoverPage luistert om de detailpagina te openen.
  static final gameDetailRequest =
      ValueNotifier<
        ({int gameId, String fallbackTitle, String? fallbackCoverUrl})?
      >(null);

  /// Signaal om de lijst terug naar boven te scrollen.
  static final scrollToTopRequest = ValueNotifier<int>(0);

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const int _pageSize = 20;
  static const Duration _searchDebounce = Duration(milliseconds: 800);

  /// RAWG API-sleutel uit het .env-bestand.
  String get _rawgApiKey => SecureStorageService.rawgApiKey;

  /// True als de camera-knop getoond moet worden (alleen iOS en Android).
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

  /// 1 = lijst (één rij per game), 2 = grid (2 kolommen), 3 = grid (3 kolommen).
  int _gridColumns =
      ViewPreferences.defaultDiscoverGridColumns; // 2 of 3 kolommen

  @override
  /// Initialiseert de pagina: laadt weergavevoorkeuren, registreert listeners en haalt eerste games op.
  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _scrollController.addListener(_onScroll);
    DiscoverPage.gameDetailRequest.addListener(_onGameDetailRequest);
    DiscoverPage.scrollToTopRequest.addListener(_onScrollToTop);
    _fetchGames(reset: true);
    // Verwerk verzoeken die al vóór de eerste build binnenkwamen.
    if (DiscoverPage.gameDetailRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onGameDetailRequest(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slowConnectionTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _httpClient.close();
    DiscoverPage.gameDetailRequest.removeListener(_onGameDetailRequest);
    DiscoverPage.scrollToTopRequest.removeListener(_onScrollToTop);
    super.dispose();
  }

  /// Scrollt de lijst naar boven als het signaal wordt ontvangen.
  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Verwerkt een verzoek vanuit de shell om een spel-detailpagina te openen.
  void _onGameDetailRequest() {
    final request = DiscoverPage.gameDetailRequest.value;
    if (request == null || !mounted) return;
    DiscoverPage.gameDetailRequest.value = null;
    // Uitstellen zodat de tabwissel eerst volledig gerenderd is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Verwijder eventuele verouderde detailpagina's zodat er nooit meer dan één terugknop is.
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameDetailPage(
            gameId: request.gameId,
            fallbackTitle: request.fallbackTitle,
            fallbackCoverUrl: request.fallbackCoverUrl,
          ),
        ),
      );
    });
  }

  /// Luistert op de scrollpositie en triggert infinite scroll als de bodem nadert.
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

  /// Haalt games op van de RAWG API. [reset] herstart de lijst; [loadMore] laadt de volgende pagina.
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
        // Filter en sorteer alléén de gloednieuwe uit de API opgehaalde games
        final processedNewGames = _sortGamesByRelevance(
          page.games,
          _activeQuery,
        );

        if (loadMore) {
          // Voeg de nieuwe games onderaan toe, zo springen de bestaande games op het scherm niet meer rond
          _games = [..._games, ...processedNewGames];

          // Stop met het inladen van onzin als we zoeken:
          // Als er uit deze RAWG-pagina nul RELEVANTE games overbleven, kappen we de infinite scroll af.
          if (_activeQuery.isNotEmpty && processedNewGames.isEmpty) {
            _nextPageUrl = null;
          } else {
            _nextPageUrl = page.nextPageUrl;
          }
        } else {
          // Dit is de eerste lading, dus we overschrijven de lijst gewoon.
          _games = processedNewGames;
          _nextPageUrl = page.nextPageUrl;
        }

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

  /// Debounced handler voor tekstwijzigingen in de zoekbalk.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      final query = value.trim();

      // Minimaliseer API-verzoeken: start pas met zoeken na minimaal 2 tekens.
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

  /// Voert direct een zoekopdracht uit als de gebruiker op 'Zoeken' tikt.
  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query == _activeQuery) {
      return;
    }

    _activeQuery = query;
    _fetchGames(reset: true);
  }

  /// Wist de zoekbalk en herstelt de standaard gamelijst.
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

    // Verwijder games die absoluut niks te maken hebben met de zoekterm
    final validGames = games.where((g) {
      final normalizedTitle = _normalizeSearchText(g.title);
      if (normalizedTitle.contains(normalizedQuery)) return true;
      for (final t in queryTokens) {
        if (normalizedTitle.contains(t)) return true;
      }
      return false;
    }).toList();

    validGames.sort((a, b) {
      final scoreA = _scoreGameRelevance(a.title, normalizedQuery, queryTokens);
      final scoreB = _scoreGameRelevance(b.title, normalizedQuery, queryTokens);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return validGames;
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

  /// Toont een korte snackbar met een bericht.
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

  /// Opent de camera en start het coverherkenningsproces via Google Lens.
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
              color: AppTheme.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DiscoverSearchBar(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            onSubmitted: _onSearchSubmitted,
                            onClearPressed: _clearSearch,
                            showCameraButton: false,
                            onCameraPressed: _openCamera,
                            isCameraBusy: false,
                            isCameraDisabled:
                                _isOpeningCamera || _isRecognizingCover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: _layoutCycleTooltip,
                          icon: Icon(
                            _layoutCycleIcon,
                            color: AppTheme.orange500,
                          ),
                          onPressed: _cycleLayout,
                        ),
                        if (_showCameraButton)
                          IconButton(
                            tooltip: 'Cover scannen',
                            icon: const Icon(
                              LucideIcons.camera,
                              color: AppTheme.orange500,
                            ),
                            onPressed: (_isOpeningCamera || _isRecognizingCover)
                                ? null
                                : _openCamera,
                          ),
                      ],
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

  /// Wisselt tussen 2- en 3-koloms rasterweergave en slaat de keuze op.
  void _cycleLayout() {
    setState(() {
      _gridColumns = _gridColumns == 2 ? 3 : 2;
    });
    ViewPreferences.setDiscoverGridColumns(_gridColumns);
  }

  /// Laadt de opgeslagen rastervoorkeur en past de UI aan.
  Future<void> _loadViewPreference() async {
    final value = await ViewPreferences.getDiscoverGridColumns();
    if (!mounted) return;
    if (value != _gridColumns) {
      setState(() => _gridColumns = value);
    }
  }

  /// Geeft het icoon voor de volgende rasterschakelstand.
  IconData get _layoutCycleIcon {
    // Toon het icoon dat past bij de VOLGENDE stand.
    return _gridColumns == 2 ? LucideIcons.grid3x3 : LucideIcons.layoutGrid;
  }

  /// Geeft de tooltip-tekst voor de rasterschakelknop.
  String get _layoutCycleTooltip {
    return _gridColumns == 2
        ? 'Toon als 3-koloms raster'
        : 'Toon als 2-koloms raster';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.searchX, size: 48, color: AppTheme.orange500),
              const SizedBox(height: 16),
              Text(
                'Geen games gevonden.',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Probeer een andere zoekterm of pas de filters aan.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.gray500),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGridView(textTheme, _gridColumns);
  }

  Widget _buildGridView(TextTheme textTheme, int columns) {
    final extraLoadingTiles = _isLoadingMore ? columns : 0;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2 / 3,
      ),
      itemCount: _games.length + extraLoadingTiles,
      itemBuilder: (context, index) {
        if (index >= _games.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final game = _games[index];
        return _ScaleTap(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameDetailPage(
                  gameId: game.id,
                  fallbackTitle: game.title,
                  fallbackCoverUrl: game.coverUrl,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppTheme.orange50,
                  child: game.coverUrl == null
                      ? Icon(
                          LucideIcons.gamepad2,
                          size: 34,
                          color: AppTheme.gray300,
                        )
                      : Image.network(
                          game.coverUrl!,
                          fit: BoxFit.cover,
                          semanticLabel: 'Omslagafbeelding van ${game.title}',
                          errorBuilder: (_, __, ___) => Icon(
                            LucideIcons.gamepad2,
                            size: 34,
                            color: AppTheme.gray300,
                          ),
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      columns == 3 ? 8 : 10,
                      columns == 3 ? 20 : 28,
                      columns == 3 ? 8 : 10,
                      columns == 3 ? 6 : 8,
                    ),
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
                      style:
                          (columns == 3
                                  ? textTheme.bodySmall
                                  : textTheme.bodyMedium)
                              ?.copyWith(
                                color: AppTheme.trueWhite,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                ),
              ],
            ),
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

    // Expliciete internetcontrole om snel te falen bij een SocketException.
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _handleError('NETWORK_ERROR');
      }
    } on SocketException catch (_) {
      _handleError('NETWORK_ERROR');
    } catch (_) {
      // Genegeerd; laat de webview andere fouten afhandelen.
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
        // Hidden rendering of webview (needs to have size + opacity to bypass lazy-loading/rendering optimizations of WebKit)
        Opacity(
          opacity: 0.01,
          child: SizedBox(
            height: 150,
            width: 150,
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
        Container(
          color: AppTheme
              .white, // Covers the tiny dot of 0.01 opacity just in case
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
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray700,
                  ),
                  child: const Text('Annuleren'),
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

/// Scale-on-press microinteraction wrapper.
class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTap({required this.child, required this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
