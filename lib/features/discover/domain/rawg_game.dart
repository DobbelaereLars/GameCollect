class RawgGame {
  const RawgGame({required this.title, required this.coverUrl});

  final String title;
  final String? coverUrl;

  factory RawgGame.fromJson(Map<String, dynamic> json) {
    return RawgGame(
      title: json['name'] as String? ?? 'Onbekende game',
      coverUrl: json['background_image'] as String?,
    );
  }
}
