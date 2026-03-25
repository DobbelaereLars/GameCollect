import 'dart:convert';

class CollectionItem {
  final int? id;
  final int apiId;
  final String title;
  final String? coverUrl;
  final String? publisher;
  final String format; // 'Fysiek', 'Digitaal', 'Allebei'
  final List<String> selectedPlatforms;
  final List<String> tags;
  final DateTime addedAt;

  CollectionItem({
    this.id,
    required this.apiId,
    required this.title,
    this.coverUrl,
    this.publisher,
    required this.format,
    required this.selectedPlatforms,
    required this.tags,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apiId': apiId,
      'title': title,
      'coverUrl': coverUrl,
      'publisher': publisher,
      'format': format,
      'selectedPlatforms': jsonEncode(selectedPlatforms),
      'tags': jsonEncode(tags),
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    return CollectionItem(
      id: map['id'] as int?,
      apiId: map['apiId'] as int,
      title: map['title'] as String,
      coverUrl: map['coverUrl'] as String?,
      publisher: map['publisher'] as String?,
      format: map['format'] as String,
      selectedPlatforms: List<String>.from(
        jsonDecode(map['selectedPlatforms'] as String),
      ),
      tags: List<String>.from(jsonDecode(map['tags'] as String)),
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }
}
