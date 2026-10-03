import 'package:flutter/material.dart';
import 'models/media_item.dart';
import 'models/playlist.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

class DeeprowsPlayerApp extends StatefulWidget {
  const DeeprowsPlayerApp({super.key});

  @override
  State<DeeprowsPlayerApp> createState() => _DeeprowsPlayerAppState();
}

class _DeeprowsPlayerAppState extends State<DeeprowsPlayerApp> {
  final StorageService storage = StorageService();
  List<Playlist> playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await storage.loadPlaylists();
    if (!mounted) return;
    setState(() => playlists = loaded);
  }

  Future<void> savePlaylists(List<Playlist> value) async {
    setState(() => playlists = value);
    await storage.savePlaylists(value);
  }

  Future<void> addToPlaylist(MediaItem item) async {
    final next = playlists.isEmpty
        ? [
            Playlist(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: 'My Playlist',
              items: [item],
            )
          ]
        : playlists.map((p) {
            if (p.id != playlists.first.id) return p;
            return p.copyWith(items: [...p.items, item]);
          }).toList();

    await savePlaylists(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DP Deeprows Player',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(
        playlists: playlists,
        onPlaylistsChanged: savePlaylists,
        onAddToPlaylist: addToPlaylist,
      ),
    );
  }
}
