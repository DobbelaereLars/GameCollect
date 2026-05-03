import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/rawg_game.dart';

/// Bevat een pagina met games en de URL van de volgende pagina (of null).
class RawgGamesPage {
  const RawgGamesPage({required this.games, required this.nextPageUrl});

  /// Lijst met games op deze pagina.
  final List<RawgGame> games;

  /// URL voor de volgende pagina, of null als dit de laatste pagina is.
  final String? nextPageUrl;
}

/// Client voor de RAWG Games API.
class RawgGamesApi {
  const RawgGamesApi();

  /// Gemeenschappelijke helper: voert een GET-verzoek uit op [uri] en
  /// parseert het resultaat naar een [RawgGamesPage].
  Future<RawgGamesPage> _fetchGamesFromUri(http.Client client, Uri uri) async {
    final response = await client.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('RAWG request mislukt (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final games = (decoded['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RawgGame.fromJson)
        .toList(growable: false);

    return RawgGamesPage(games: games, nextPageUrl: decoded['next'] as String?);
  }

  /// Haalt een pagina games op. Zoekt op [activeQuery] als die niet leeg is,
  /// anders de meest recent toegevoegde games. Hervat paginering via [nextPageUrl].
  Future<RawgGamesPage> fetchGames({
    required http.Client client,
    required String apiKey,
    required int pageSize,
    required String activeQuery,
    String? nextPageUrl,
  }) {
    final uri = nextPageUrl != null
        ? Uri.parse(nextPageUrl)
        : Uri.https('api.rawg.io', '/api/games', {
            'key': apiKey,
            'page_size': '$pageSize',
            if (activeQuery.isEmpty) 'ordering': '-added',
            if (activeQuery.isNotEmpty) 'search': activeQuery,
            if (activeQuery.isNotEmpty) 'search_precise': 'true',
          });

    return _fetchGamesFromUri(client, uri);
  }

  /// Haalt de best beoordeelde games op (gesorteerd op Metacritic-score).
  Future<RawgGamesPage> fetchTopRatedGames({
    required http.Client client,
    required String apiKey,
    required int pageSize,
  }) {
    final uri = Uri.https('api.rawg.io', '/api/games', {
      'key': apiKey,
      'page_size': '$pageSize',
      'ordering': '-metacritic',
      'metacritic': '1,100',
    });

    return _fetchGamesFromUri(client, uri);
  }

  /// Haalt uitgebreide details op voor één spel via zijn RAWG-ID.
  Future<RawgGameDetails> fetchGameDetails({
    required http.Client client,
    required String apiKey,
    required int id,
  }) async {
    final uri = Uri.https('api.rawg.io', '/api/games/$id', {'key': apiKey});

    final response = await client.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('RAWG request mislukt (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return RawgGameDetails.fromJson(decoded);
  }

  /// Haalt alle achievements op voor een spel (doorloopt meerdere pagina's als nodig).
  Future<List<RawgAchievement>> fetchGameAchievements({
    required http.Client client,
    required String apiKey,
    required int id,
  }) async {
    final all = <RawgAchievement>[];
    String? nextUrl = Uri.https('api.rawg.io', '/api/games/$id/achievements', {
      'key': apiKey,
      'page_size': '40',
    }).toString();

    while (nextUrl != null) {
      final response = await client
          .get(Uri.parse(nextUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception(
          'RAWG achievements request mislukt (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? const [];

      all.addAll(
        results.whereType<Map<String, dynamic>>().map(RawgAchievement.fromJson),
      );

      nextUrl = decoded['next'] as String?;
    }

    return List.unmodifiable(all);
  }
}
