import '../domain/rawg_game.dart';

/// Hulpfuncties voor het zoeken en rangschikken van games op relevantie.
///
/// Bevat puur logica zonder afhankelijkheid van Flutter-widgets of de UI-laag.
/// Kan daardoor onafhankelijk worden getest en hergebruikt.
abstract final class GameSearchUtils {
  /// Rangschikt [games] op relevantie ten opzichte van [query].
  ///
  /// Games die geen enkele overeenkomst vertonen met de zoekterm worden
  /// gefilterd. Games met een exacte of gedeeltelijke titel-match krijgen
  /// een hogere score.
  static List<RawgGame> sortByRelevance(List<RawgGame> games, String query) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) {
      return games;
    }

    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    // Verwijder games die absoluut niks te maken hebben met de zoekterm.
    final validGames = games.where((g) {
      final normalizedTitle = normalizeText(g.title);
      if (normalizedTitle.contains(normalizedQuery)) return true;
      for (final t in queryTokens) {
        if (normalizedTitle.contains(t)) return true;
      }
      return false;
    }).toList();

    validGames.sort((a, b) {
      final scoreA = _scoreRelevance(a.title, normalizedQuery, queryTokens);
      final scoreB = _scoreRelevance(b.title, normalizedQuery, queryTokens);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return validGames;
  }

  /// Normaliseert tekst naar lowercase zonder speciale tekens voor vergelijking.
  static String normalizeText(String value) {
    final lowercase = value.toLowerCase();
    final noSpecialChars = lowercase.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    return noSpecialChars.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Berekent een relevantieco voor [title] ten opzichte van [normalizedQuery].
  static int _scoreRelevance(
    String title,
    String normalizedQuery,
    List<String> queryTokens,
  ) {
    final normalizedTitle = normalizeText(title);
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
}
