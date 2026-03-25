import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../data/rawg_games_api.dart';
import '../domain/rawg_game.dart';

class GameDetailPage extends StatefulWidget {
  final int gameId;
  final String fallbackTitle;
  final String? fallbackCoverUrl;

  const GameDetailPage({
    super.key,
    required this.gameId,
    required this.fallbackTitle,
    this.fallbackCoverUrl,
  });

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final http.Client _httpClient = http.Client();
  final RawgGamesApi _rawgGamesApi = const RawgGamesApi();

  bool _isLoading = true;
  String? _errorMessage;
  RawgGameDetails? _gameDetails;
  Timer? _slowConnectionTimer;
  bool _isSlowConnection = false;

  String get _rawgApiKey => dotenv.env['RAWG_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _fetchGameDetails();
  }

  @override
  void dispose() {
    _httpClient.close();
    _slowConnectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGameDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSlowConnection = false;
    });

    _slowConnectionTimer?.cancel();
    _slowConnectionTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isSlowConnection = true;
        });
      }
    });

    try {
      if (_rawgApiKey.isEmpty) {
        throw Exception('RAWG API key ontbreekt.');
      }

      final details = await _rawgGamesApi.fetchGameDetails(
        client: _httpClient,
        apiKey: _rawgApiKey,
        id: widget.gameId,
      );

      if (!mounted) return;

      setState(() {
        _gameDetails = details;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final isNetworkError =
          error is SocketException ||
          error is TimeoutException ||
          error.toString().contains('SocketException') ||
          error.toString().contains('ClientException');

      setState(() {
        _isLoading = false;
        if (isNetworkError) {
          _errorMessage = 'Controleer je internetverbinding';
        } else {
          _errorMessage = 'Er is iets misgegaan.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = _gameDetails?.coverUrl ?? widget.fallbackCoverUrl;
    final title = _gameDetails?.title ?? widget.fallbackTitle;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: textTheme.titleLarge?.copyWith(color: AppTheme.black),
        ),
      ),
      body: _buildBody(textTheme, coverUrl),
    );
  }

  Widget _buildBody(TextTheme textTheme, String? coverUrl) {
    if (_isLoading) {
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
                onPressed: _fetchGameDetails,
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

    if (_gameDetails == null) {
      return Center(
        child: Text('Geen game gegevens gevonden.', style: textTheme.bodyLarge),
      );
    }

    final game = _gameDetails!;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover Image View
          if (coverUrl != null)
            Container(
              height: 300,
              width: double.infinity,
              color: AppTheme.orange50,
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      LucideIcons.gamepad2,
                      size: 64,
                      color: AppTheme.gray500,
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: textTheme.displayLarge?.copyWith(
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 12),

                if (game.released != null || game.rating != null) ...[
                  Row(
                    children: [
                      if (game.released != null) ...[
                        Icon(
                          LucideIcons.calendar,
                          size: 16,
                          color: AppTheme.gray700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.released!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (game.released != null && game.rating != null)
                        const SizedBox(width: 16),
                      if (game.rating != null && game.rating! > 0) ...[
                        Icon(
                          LucideIcons.star,
                          size: 16,
                          color: AppTheme.orange500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.rating!.toStringAsFixed(1),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.orange500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Platform tags
                if (game.platforms.isNotEmpty) ...[
                  Text(
                    'Platforms',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: game.platforms.map((platform) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.orange50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.orange100),
                        ),
                        child: Text(
                          platform,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.orange700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Description
                if (game.description.isNotEmpty) ...[
                  Text(
                    'Over de game',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray700,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Metadata list
                _buildMetadataList(textTheme, game),

                // Extra padding onderaan zodat de content niet achter de (floating) bottom navigation bar valt
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataList(TextTheme textTheme, RawgGameDetails game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (game.genres.isNotEmpty)
          _buildMetadataRow(textTheme, 'Genres', game.genres.join(', ')),
        if (game.developers.isNotEmpty)
          _buildMetadataRow(
            textTheme,
            'Ontwikkelaar',
            game.developers.join(', '),
          ),
        if (game.publishers.isNotEmpty)
          _buildMetadataRow(textTheme, 'Uitgever', game.publishers.join(', ')),
        if (game.ageRating != null)
          _buildMetadataRow(
            textTheme,
            'Leeftijdsclassificatie',
            game.ageRating!,
          ),
        if (game.tags.isNotEmpty)
          _buildMetadataRow(
            textTheme,
            'Tags',
            game.tags.take(8).join(', ') + (game.tags.length > 8 ? '...' : ''),
          ),
      ],
    );
  }

  Widget _buildMetadataRow(TextTheme textTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.gray500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(color: AppTheme.black),
          ),
        ],
      ),
    );
  }
}
