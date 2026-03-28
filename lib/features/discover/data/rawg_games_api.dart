import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/rawg_game.dart';

class RawgGamesPage {
  const RawgGamesPage({required this.games, required this.nextPageUrl});

  final List<RawgGame> games;
  final String? nextPageUrl;
}

class RawgGamesApi {
  const RawgGamesApi();

  Future<RawgGamesPage> fetchGames({
    required http.Client client,
    required String apiKey,
    required int pageSize,
    required String activeQuery,
    String? nextPageUrl,
  }) async {
    final uri = nextPageUrl != null
        ? Uri.parse(nextPageUrl)
        : Uri.https('api.rawg.io', '/api/games', {
            'key': apiKey,
            'page_size': '$pageSize',
            if (activeQuery.isEmpty) 'ordering': '-added',
            if (activeQuery.isNotEmpty) 'search': activeQuery,
            if (activeQuery.isNotEmpty) 'search_precise': 'true',
          });

    final response = await client.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('RAWG request mislukt (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? const [];
    final next = decoded['next'] as String?;

    final games = results
        .whereType<Map<String, dynamic>>()
        .map(RawgGame.fromJson)
        .toList(growable: false);

    return RawgGamesPage(games: games, nextPageUrl: next);
  }

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
        results
            .whereType<Map<String, dynamic>>()
            .map(RawgAchievement.fromJson),
      );

      nextUrl = decoded['next'] as String?;
    }

    return List.unmodifiable(all);
  }
}
