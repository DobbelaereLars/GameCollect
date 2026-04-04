import 'dart:convert';

class PlaytimeEntry {
  const PlaytimeEntry({
    required this.id,
    required this.date,
    required this.minutes,
    required this.addedAt,
  });

  final String id;
  final String date;
  final int minutes;
  final DateTime addedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'minutes': minutes,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory PlaytimeEntry.fromMap(Map<String, dynamic> map) {
    final date = map['date'] as String? ?? '';
    final id = map['id'] as String? ?? '${date}_legacy';
    final addedAt = map['addedAt'] != null
        ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    return PlaytimeEntry(
      id: id,
      date: date,
      minutes: map['minutes'] as int? ?? 0,
      addedAt: addedAt,
    );
  }
}

class AchievementState {
  const AchievementState({
    required this.rawgId,
    required this.isCompleted,
    required this.isEnabled,
  });

  final int rawgId;
  final bool isCompleted;
  final bool isEnabled;

  AchievementState copyWith({int? rawgId, bool? isCompleted, bool? isEnabled}) {
    return AchievementState(
      rawgId: rawgId ?? this.rawgId,
      isCompleted: isCompleted ?? this.isCompleted,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rawgId': rawgId,
      'isCompleted': isCompleted,
      'isEnabled': isEnabled,
    };
  }

  factory AchievementState.fromMap(Map<String, dynamic> map) {
    return AchievementState(
      rawgId: map['rawgId'] as int? ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

class GameAchievementWithState {
  const GameAchievementWithState({
    required this.rawgId,
    required this.name,
    required this.description,
    this.imageUrl,
    this.percent,
    required this.isCompleted,
    required this.isEnabled,
  });

  final int rawgId;
  final String name;
  final String description;
  final String? imageUrl;
  final double? percent;
  final bool isCompleted;
  final bool isEnabled;

  GameAchievementWithState copyWith({
    int? rawgId,
    String? name,
    String? description,
    String? imageUrl,
    double? percent,
    bool? isCompleted,
    bool? isEnabled,
  }) {
    return GameAchievementWithState(
      rawgId: rawgId ?? this.rawgId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      percent: percent ?? this.percent,
      isCompleted: isCompleted ?? this.isCompleted,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class CustomRequirement {
  const CustomRequirement({
    required this.id,
    this.title,
    required this.description,
    required this.isCompleted,
    required this.isEnabled,
  });

  final String id;
  final String? title;
  final String description;
  final bool isCompleted;
  final bool isEnabled;

  CustomRequirement copyWith({
    String? id,
    String? description,
    bool? isCompleted,
    bool? isEnabled,
  }) {
    return CustomRequirement(
      id: id ?? this.id,
      title: title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isEnabled': isEnabled,
    };
  }

  factory CustomRequirement.fromMap(Map<String, dynamic> map) {
    return CustomRequirement(
      id: map['id'] as String? ?? '',
      title: map['title'] as String?,
      description: map['description'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

class CollectionItem {
  final int? id;
  final int apiId;
  final String title;
  final String? coverUrl;
  final String? customCoverPath;
  final String? publisher;
  final String format; // 'Fysiek', 'Digitaal', 'Allebei'
  final List<String> selectedPlatforms;
  final List<String> suggestedTags;
  final List<String> selectedSuggestedTags;
  final List<String> customTags;
  final List<String> selectedCustomTags;
  final String notes;
  final List<PlaytimeEntry> playtimeEntries;
  final List<AchievementState> achievementStates;
  final List<CustomRequirement> requirements;
  final DateTime addedAt;
  final bool isManuallyCompleted;
  final DateTime? startedPlayingAt;
  final List<String> availablePlatforms;

  CollectionItem({
    this.id,
    required this.apiId,
    required this.title,
    this.coverUrl,
    this.customCoverPath,
    this.publisher,
    required this.format,
    List<String>? selectedPlatforms,
    List<String>? suggestedTags,
    List<String>? selectedSuggestedTags,
    List<String>? customTags,
    List<String>? selectedCustomTags,
    required this.notes,
    List<PlaytimeEntry>? playtimeEntries,
    List<AchievementState>? achievementStates,
    List<CustomRequirement>? requirements,
    required this.addedAt,
    this.isManuallyCompleted = false,
    this.startedPlayingAt,
    List<String>? availablePlatforms,
  }) : selectedPlatforms = List<String>.from(selectedPlatforms ?? const []),
       availablePlatforms = List<String>.from(availablePlatforms ?? const []),
       suggestedTags = List<String>.from(suggestedTags ?? const []),
       selectedSuggestedTags = List<String>.from(
         selectedSuggestedTags ?? const [],
       ),
       customTags = List<String>.from(customTags ?? const []),
       selectedCustomTags = List<String>.from(selectedCustomTags ?? const []),
       playtimeEntries = List<PlaytimeEntry>.from(playtimeEntries ?? const []),
       achievementStates = List<AchievementState>.from(
         achievementStates ?? const [],
       ),
       requirements = List<CustomRequirement>.from(requirements ?? const []);

  CollectionItem copyWith({
    int? id,
    int? apiId,
    String? title,
    String? coverUrl,
    String? customCoverPath,
    bool clearCustomCoverPath = false,
    String? publisher,
    String? format,
    List<String>? selectedPlatforms,
    List<String>? suggestedTags,
    List<String>? selectedSuggestedTags,
    List<String>? customTags,
    List<String>? selectedCustomTags,
    String? notes,
    List<PlaytimeEntry>? playtimeEntries,
    List<AchievementState>? achievementStates,
    List<CustomRequirement>? requirements,
    DateTime? addedAt,
    bool? isManuallyCompleted,
    DateTime? startedPlayingAt,
    bool clearStartedPlayingAt = false,
    List<String>? availablePlatforms,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      apiId: apiId ?? this.apiId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      customCoverPath: clearCustomCoverPath
          ? null
          : (customCoverPath ?? this.customCoverPath),
      publisher: publisher ?? this.publisher,
      format: format ?? this.format,
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      selectedSuggestedTags:
          selectedSuggestedTags ?? this.selectedSuggestedTags,
      customTags: customTags ?? this.customTags,
      selectedCustomTags: selectedCustomTags ?? this.selectedCustomTags,
      notes: notes ?? this.notes,
      playtimeEntries: playtimeEntries ?? this.playtimeEntries,
      achievementStates: achievementStates ?? this.achievementStates,
      requirements: requirements ?? this.requirements,
      addedAt: addedAt ?? this.addedAt,
      isManuallyCompleted: isManuallyCompleted ?? this.isManuallyCompleted,
      startedPlayingAt: clearStartedPlayingAt
          ? null
          : (startedPlayingAt ?? this.startedPlayingAt),
      availablePlatforms: availablePlatforms ?? this.availablePlatforms,
    );
  }

  List<String> get activeTags {
    return {
      ...selectedSuggestedTags,
      ...selectedCustomTags.where((tag) => customTags.contains(tag)),
    }.toList(growable: false);
  }

  double get progressRatio {
    if (isManuallyCompleted) return 1.0;
    final enabledAch = achievementStates.where((s) => s.isEnabled).toList();
    final enabledReq = requirements.where((r) => r.isEnabled).toList();
    final total = enabledAch.length + enabledReq.length;
    if (total == 0) return 0;
    final completed =
        enabledAch.where((s) => s.isCompleted).length +
        enabledReq.where((r) => r.isCompleted).length;
    return completed / total;
  }

  int get totalPlaytimeMinutes {
    return playtimeEntries.fold<int>(0, (sum, e) => sum + e.minutes);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apiId': apiId,
      'title': title,
      'coverUrl': coverUrl,
      'customCoverPath': customCoverPath,
      'publisher': publisher,
      'format': format,
      'selectedPlatforms': jsonEncode(selectedPlatforms),
      'tags': jsonEncode(activeTags),
      'suggestedTags': jsonEncode(suggestedTags),
      'selectedSuggestedTags': jsonEncode(selectedSuggestedTags),
      'customTags': jsonEncode(customTags),
      'selectedCustomTags': jsonEncode(selectedCustomTags),
      'notes': notes,
      'playtimeEntries': jsonEncode(
        playtimeEntries.map((e) => e.toMap()).toList(),
      ),
      'achievementStates': jsonEncode(
        achievementStates.map((s) => s.toMap()).toList(),
      ),
      'requirements': jsonEncode(requirements.map((r) => r.toMap()).toList()),
      'addedAt': addedAt.toIso8601String(),
      'isManuallyCompleted': isManuallyCompleted ? 1 : 0,
      'startedPlayingAt': startedPlayingAt?.toIso8601String(),
      'availablePlatforms': jsonEncode(availablePlatforms),
    };
  }

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic value) {
      if (value is! String || value.isEmpty) {
        return <String>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List<dynamic>) {
          return <String>[];
        }
        return decoded.whereType<String>().toList(growable: false);
      } catch (_) {
        return <String>[];
      }
    }

    List<PlaytimeEntry> parsePlaytimeEntries(dynamic value) {
      if (value is! String || value.isEmpty) {
        return const <PlaytimeEntry>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List<dynamic>) {
          return const <PlaytimeEntry>[];
        }
        return decoded
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(PlaytimeEntry.fromMap)
            .toList(growable: false);
      } catch (_) {
        return const <PlaytimeEntry>[];
      }
    }

    List<AchievementState> parseAchievementStates(dynamic value) {
      if (value is! String || value.isEmpty) {
        return const <AchievementState>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List<dynamic>) {
          return const <AchievementState>[];
        }
        return decoded
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(AchievementState.fromMap)
            .toList(growable: false);
      } catch (_) {
        return const <AchievementState>[];
      }
    }

    List<CustomRequirement> parseRequirements(dynamic value) {
      if (value is! String || value.isEmpty) {
        return const <CustomRequirement>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List<dynamic>) {
          return const <CustomRequirement>[];
        }
        return decoded
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(CustomRequirement.fromMap)
            .toList(growable: false);
      } catch (_) {
        return const <CustomRequirement>[];
      }
    }

    final legacyTags = parseStringList(map['tags']);
    final suggestedTags = parseStringList(map['suggestedTags']);
    final selectedSuggestedTags = parseStringList(map['selectedSuggestedTags']);
    final customTags = parseStringList(map['customTags']);
    final selectedCustomTags = parseStringList(map['selectedCustomTags']);

    return CollectionItem(
      id: map['id'] as int?,
      apiId: map['apiId'] as int? ?? 0,
      title: map['title'] as String? ?? 'Onbekende game',
      coverUrl: map['coverUrl'] as String?,
      customCoverPath: map['customCoverPath'] as String?,
      publisher: map['publisher'] as String?,
      format: map['format'] as String? ?? 'Fysiek',
      selectedPlatforms: parseStringList(map['selectedPlatforms']),
      suggestedTags: suggestedTags,
      selectedSuggestedTags: selectedSuggestedTags.isEmpty
          ? legacyTags.where((tag) => suggestedTags.contains(tag)).toList()
          : selectedSuggestedTags,
      customTags: customTags.isEmpty
          ? legacyTags.where((tag) => !suggestedTags.contains(tag)).toList()
          : customTags,
      selectedCustomTags: selectedCustomTags.isEmpty
          ? (customTags.isEmpty
                ? legacyTags
                      .where((tag) => !suggestedTags.contains(tag))
                      .toList()
                : customTags)
          : selectedCustomTags
                .where((tag) => customTags.contains(tag))
                .toList(),
      notes: map['notes'] as String? ?? '',
      playtimeEntries: parsePlaytimeEntries(map['playtimeEntries']),
      achievementStates: parseAchievementStates(map['achievementStates']),
      requirements: parseRequirements(map['requirements']),
      addedAt: DateTime.parse(map['addedAt'] as String),
      isManuallyCompleted: (map['isManuallyCompleted'] as int? ?? 0) != 0,
      startedPlayingAt: map['startedPlayingAt'] != null
          ? DateTime.tryParse(map['startedPlayingAt'] as String)
          : null,
      availablePlatforms: parseStringList(map['availablePlatforms']),
    );
  }
}
