import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const int _pageSize = 20;
  static const Duration _searchDebounce = Duration(milliseconds: 800);

  String get _rawgApiKey => dotenv.env['RAWG_API_KEY'] ?? '';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final http.Client _httpClient = http.Client();

  Timer? _debounce;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _activeQuery = '';
  List<_RawgGame> _games = const [];
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

    try {
      final uri = loadMore
          ? Uri.parse(_nextPageUrl!)
          : Uri.https('api.rawg.io', '/api/games', {
              'key': _rawgApiKey,
              'page_size': '$_pageSize',
              'ordering': '-added',
              if (_activeQuery.isNotEmpty) 'search': _activeQuery,
            });

      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('RAWG request mislukt (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? const [];
      final nextPageUrl = decoded['next'] as String?;

      final games = results
          .whereType<Map<String, dynamic>>()
          .map(_RawgGame.fromJson)
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _games = loadMore ? [..._games, ...games] : games;
        _nextPageUrl = nextPageUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Kon games niet ophalen. Probeer opnieuw.';
        if (!loadMore) {
          _games = const [];
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
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
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppTheme.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Zoek games...',
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: AppTheme.grayTransparent50,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppTheme.orange50,
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          color: AppTheme.orange500,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFC299),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFC299),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.orange500,
                          ),
                        ),
                      ),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _fetchGames(reset: true),
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

class _RawgGame {
  const _RawgGame({required this.title, required this.coverUrl});

  final String title;
  final String? coverUrl;

  factory _RawgGame.fromJson(Map<String, dynamic> json) {
    return _RawgGame(
      title: json['name'] as String? ?? 'Onbekende game',
      coverUrl: json['background_image'] as String?,
    );
  }
}
