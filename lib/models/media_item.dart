class MediaItem {
  final String id;
  final String title;
  final String url;
  final String? group;
  final String? logo;
  final String? artist;

  const MediaItem({
    required this.id,
    required this.title,
    required this.url,
    this.group,
    this.logo,
    this.artist,
  });

  MediaItem copyWith({
    String? title,
    String? url,
    String? group,
    String? logo,
    String? artist,
  }) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      group: group ?? this.group,
      logo: logo ?? this.logo,
      artist: artist ?? this.artist,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'group': group,
        'logo': logo,
        'artist': artist,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Untitled',
        url: json['url']?.toString() ?? '',
        group: json['group']?.toString(),
        logo: json['logo']?.toString(),
        artist: json['artist']?.toString(),
      );
}
