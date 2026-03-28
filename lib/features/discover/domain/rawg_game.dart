class RawgGame {
  const RawgGame({
    required this.id,
    required this.title,
    required this.coverUrl,
  });

  final int id;
  final String title;
  final String? coverUrl;

  factory RawgGame.fromJson(Map<String, dynamic> json) {
    return RawgGame(
      id: json['id'] as int? ?? 0,
      title: json['name'] as String? ?? 'Onbekende game',
      coverUrl: json['background_image'] as String?,
    );
  }
}

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

  final int id;
  final String title;
  final String description;
  final String? coverUrl;
  final String? released;
  final double? rating;
  final List<String> platforms;
  final List<String> genres;
  final List<String> developers;
  final List<String> publishers;
  final List<String> tags;
  final String? ageRating;

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

    final esrb = json['esrb_rating'] as Map<String, dynamic>?;
    String? ageRatingName = esrb?['name'] as String?;
    if (ageRatingName != null) {
      if (ageRatingName == 'Everyone') {
        ageRatingName = 'Alle leeftijden (Everyone)';
      } else if (ageRatingName == 'Everyone 10+') {
        ageRatingName = '10+ (Everyone 10+)';
      } else if (ageRatingName == 'Teen') {
        ageRatingName = '13+ (Teen)';
      } else if (ageRatingName == 'Mature') {
        ageRatingName = '17+ (Mature)';
      } else if (ageRatingName == 'Adults Only') {
        ageRatingName = '18+ (Adults Only)';
      } else if (ageRatingName == 'Rating Pending') {
        ageRatingName = 'Beoordeling in afwachting';
      }
    }

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

class RawgAchievement {
  const RawgAchievement({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.percent,
  });

  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final double? percent;

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
