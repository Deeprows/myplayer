import 'media_item.dart';

class Playlist {
  final String id;
  final String name;
  final List<MediaItem> items;

  const Playlist({
    required this.id,
    required this.name,
    required this.items,
  });

  Playlist copyWith({
    String? name,
    List<MediaItem>? items,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? 'Playlist',
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
