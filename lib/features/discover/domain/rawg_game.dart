/// Compacte game-samenvatting zoals teruggegeven door de RAWG-lijstendpunten.
class RawgGame {
  const RawgGame({
    required this.id,
    required this.title,
    required this.coverUrl,
  });

  /// Uniek RAWG-spel-ID.
  final int id;

  /// Displaynaam van het spel.
  final String title;

  /// URL van de omslagafbeelding, of null als niet beschikbaar.
  final String? coverUrl;

  /// Maakt een [RawgGame] aan vanuit een JSON-object.
  factory RawgGame.fromJson(Map<String, dynamic> json) {
    return RawgGame(
      id: json['id'] as int? ?? 0,
      title: json['name'] as String? ?? 'Onbekende game',
      coverUrl: json['background_image'] as String?,
    );
  }
}

/// Uitgebreide gamedetails zoals teruggegeven door het RAWG detail-eindpunt.
class RawgGameDetails {
  const RawgGameDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.released,
    required this.rating,
    required this.platforms,
    required this.genres,
    required this.developers,
    required this.publishers,
    required this.tags,
    required this.ageRating,
  });

  /// Uniek RAWG-spel-ID.
  final int id;

  /// Displaynaam van het spel.
  final String title;

  /// Platte tekstomschrijving (zonder HTML-tags).
  final String description;

  /// URL van de omslagafbeelding, of null.
  final String? coverUrl;

  /// Releasedatum als tekenreeks (bijv. '2022-03-15'), of null.
  final String? released;

  /// Gemiddelde RAWG-gebruikersbeoordeling (0–5), of null.
  final double? rating;

  /// Lijst van platformen waarop het spel beschikbaar is.
  final List<String> platforms;

  /// Genres van het spel.
  final List<String> genres;

  /// Ontwikkelaar(s) van het spel.
  final List<String> developers;

  /// Uitgever(s) van het spel.
  final List<String> publishers;

  /// RAWG-tags gekoppeld aan het spel.
  final List<String> tags;

  /// Gemapt ESRB-leeftijdsadvies in leesbaar Nederlands, of null.
  final String? ageRating;

  /// Maakt een [RawgGameDetails] aan vanuit een JSON-object.
  factory RawgGameDetails.fromJson(Map<String, dynamic> json) {
    List<String> extractNames(String key) {
      if (json[key] == null) return <String>[];
      final list = json[key] as List<dynamic>? ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => e['name'] as String?)
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .toList();
    }

    final platformsList = json['platforms'] as List<dynamic>? ?? <dynamic>[];
    final platforms = platformsList
        .whereType<Map<String, dynamic>>()
        .map((p) {
          final p2 = p['platform'] as Map<String, dynamic>?;
          return p2?['name'] as String?;
        })
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();

    // Vertaaltabel voor ESRB-leeftijdskeuringen naar leesbare Nederlandse labels.
    const esrbLabels = {
      'Everyone': 'Alle leeftijden (Everyone)',
      'Everyone 10+': '10+ (Everyone 10+)',
      'Teen': '13+ (Teen)',
      'Mature': '17+ (Mature)',
      'Adults Only': '18+ (Adults Only)',
      'Rating Pending': 'Beoordeling in afwachting',
    };

    final esrb = json['esrb_rating'] as Map<String, dynamic>?;
    final rawRating = esrb?['name'] as String?;
    final ageRatingName = rawRating != null
        ? (esrbLabels[rawRating] ?? rawRating)
        : null;

    return RawgGameDetails(
      id: json['id'] as int? ?? 0,
      title: json['name'] as String? ?? 'Onbekende game',
      description:
          json['description_raw'] as String? ??
          'Geen omschrijving beschikbaar.',
      coverUrl: json['background_image'] as String?,
      released: json['released'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      platforms: platforms,
      genres: extractNames('genres'),
      developers: extractNames('developers'),
      publishers: extractNames('publishers'),
      tags: extractNames('tags'),
      ageRating: ageRatingName,
    );
  }
}

/// Eén RAWG-achievement gekoppeld aan een spel, inclusief behaaldpercentage.
class RawgAchievement {
  const RawgAchievement({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.percent,
  });

  /// Uniek RAWG-achievement-ID.
  final int id;

  /// Naam van het achievement.
  final String name;

  /// Omschrijving van de benodigde actie.
  final String description;

  /// URL van het achievement-icoon, of null.
  final String? imageUrl;

  /// Percentage spelers dat dit achievement heeft behaald (0–100), of null.
  final double? percent;

  /// Maakt een [RawgAchievement] aan vanuit een JSON-object.
  factory RawgAchievement.fromJson(Map<String, dynamic> json) {
    return RawgAchievement(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Onbekende achievement',
      description: json['description'] as String? ?? '',
      imageUrl: json['image'] as String?,
      percent: switch (json['percent']) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      },
    );
  }
}
