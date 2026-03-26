import 'dart:convert';

class PlaytimeEntry {
  const PlaytimeEntry({required this.date, required this.minutes});

  final String date;
  final int minutes;

  Map<String, dynamic> toMap() {
    return {'date': date, 'minutes': minutes};
  }

  factory PlaytimeEntry.fromMap(Map<String, dynamic> map) {
    return PlaytimeEntry(
      date: map['date'] as String? ?? '',
      minutes: map['minutes'] as int? ?? 0,
    );
  }
}

class GameRequirement {
  const GameRequirement({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isCustom,
    required this.isEnabled,
  });

  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isCustom;
  final bool isEnabled;

  GameRequirement copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    bool? isCustom,
    bool? isEnabled,
  }) {
    return GameRequirement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isCustom: isCustom ?? this.isCustom,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isCustom': isCustom,
      'isEnabled': isEnabled,
    };
  }

  factory GameRequirement.fromMap(Map<String, dynamic> map) {
    return GameRequirement(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      isCustom: map['isCustom'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

class CollectionItem {
  final int? id;
  final int apiId;
  final String title;
  final String? coverUrl;
  final String? publisher;
  final String format; // 'Fysiek', 'Digitaal', 'Allebei'
  final List<String> selectedPlatforms;
  final List<String> suggestedTags;
  final List<String> selectedSuggestedTags;
  final List<String> customTags;
  final List<String> selectedCustomTags;
  final String notes;
  final List<PlaytimeEntry> playtimeEntries;
  final List<GameRequirement> requirements;
  final bool isManuallyCompleted;
  final DateTime addedAt;

  CollectionItem({
    this.id,
    required this.apiId,
    required this.title,
    this.coverUrl,
    this.publisher,
    required this.format,
    List<String>? selectedPlatforms,
    List<String>? suggestedTags,
    List<String>? selectedSuggestedTags,
    List<String>? customTags,
    List<String>? selectedCustomTags,
    required this.notes,
    List<PlaytimeEntry>? playtimeEntries,
    List<GameRequirement>? requirements,
    required this.isManuallyCompleted,
    required this.addedAt,
  }) : selectedPlatforms = List<String>.from(selectedPlatforms ?? const []),
       suggestedTags = List<String>.from(suggestedTags ?? const []),
       selectedSuggestedTags = List<String>.from(
         selectedSuggestedTags ?? const [],
       ),
       customTags = List<String>.from(customTags ?? const []),
       selectedCustomTags = List<String>.from(selectedCustomTags ?? const []),
       playtimeEntries = List<PlaytimeEntry>.from(playtimeEntries ?? const []),
       requirements = List<GameRequirement>.from(requirements ?? const []);

  CollectionItem copyWith({
    int? id,
    int? apiId,
    String? title,
    String? coverUrl,
    String? publisher,
    String? format,
    List<String>? selectedPlatforms,
    List<String>? suggestedTags,
    List<String>? selectedSuggestedTags,
    List<String>? customTags,
    List<String>? selectedCustomTags,
    String? notes,
    List<PlaytimeEntry>? playtimeEntries,
    List<GameRequirement>? requirements,
    bool? isManuallyCompleted,
    DateTime? addedAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      apiId: apiId ?? this.apiId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
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
      requirements: requirements ?? this.requirements,
      isManuallyCompleted: isManuallyCompleted ?? this.isManuallyCompleted,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  List<String> get activeTags {
    return {
      ...selectedSuggestedTags,
      ...selectedCustomTags.where((tag) => customTags.contains(tag)),
    }.toList(growable: false);
  }

  List<GameRequirement> get enabledRequirements {
    return requirements.where((r) => r.isEnabled).toList(growable: false);
  }

  int get completedEnabledRequirementsCount {
    return enabledRequirements.where((r) => r.isCompleted).length;
  }

  double get progressRatio {
    final enabled = enabledRequirements;
    if (enabled.isEmpty) {
      return isManuallyCompleted ? 1 : 0;
    }
    final completed = enabled.where((r) => r.isCompleted).length;
    return completed / enabled.length;
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
      'requirements': jsonEncode(requirements.map((e) => e.toMap()).toList()),
      'isManuallyCompleted': isManuallyCompleted ? 1 : 0,
      'addedAt': addedAt.toIso8601String(),
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

    List<GameRequirement> parseRequirements(dynamic value) {
      if (value is! String || value.isEmpty) {
        return const <GameRequirement>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List<dynamic>) {
          return const <GameRequirement>[];
        }
        return decoded
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(GameRequirement.fromMap)
            .toList(growable: false);
      } catch (_) {
        return const <GameRequirement>[];
      }
    }

    final legacyTags = parseStringList(map['tags']);
    final suggestedTags = parseStringList(map['suggestedTags']);
    final selectedSuggestedTags = parseStringList(map['selectedSuggestedTags']);
    final customTags = parseStringList(map['customTags']);
    final selectedCustomTags = parseStringList(map['selectedCustomTags']);

    return CollectionItem(
      id: map['id'] as int?,
      apiId: map['apiId'] as int,
      title: map['title'] as String,
      coverUrl: map['coverUrl'] as String?,
      publisher: map['publisher'] as String?,
      format: map['format'] as String,
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
      requirements: parseRequirements(map['requirements']),
      isManuallyCompleted: (map['isManuallyCompleted'] as int? ?? 0) == 1,
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }
}
