import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_tile.dart';
import '../widgets/player_panel.dart';

class HomeScreen extends StatefulWidget {
  final List<Playlist> playlists;
  final Future<void> Function(List<Playlist>) onPlaylistsChanged;
  final Future<void> Function(MediaItem) onAddToPlaylist;

  const HomeScreen({
    super.key,
    required this.playlists,
    required this.onPlaylistsChanged,
    required this.onAddToPlaylist,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  late final Player player;
  late final VideoController videoController;
  StreamSubscription<bool>? _completedSub;

  MediaItem? current;
  String search = '';
  String? group;
  int selectedPlaylist = 0;
  bool sidebarOpen = true;

  @override
  void initState() {
    super.initState();
    player = Player();
    // Created once. Re-creating a controller on every build leaks textures.
    videoController = VideoController(player);
    _completedSub = player.stream.completed.listen((done) {
      if (done) _playNext();
    });
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _searchController.dispose();
    player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  int get _activeIndex {
    if (widget.playlists.isEmpty) return 0;
    return selectedPlaylist.clamp(0, widget.playlists.length - 1);
  }

  Playlist? get activePlaylist =>
      widget.playlists.isEmpty ? null : widget.playlists[_activeIndex];

  List<String> get groups {
    final p = activePlaylist;
    if (p == null) return const [];
    final set = <String>{};
    for (final i in p.items) {
      final g = i.group;
      if (g != null && g.trim().isNotEmpty) set.add(g.trim());
    }
    return set.toList()..sort();
  }

  List<MediaItem> get currentItems {
    final p = activePlaylist;
    if (p == null) return [];
    Iterable<MediaItem> items = p.items;
    if (group != null) {
      items = items.where((e) => (e.group ?? '').trim() == group);
    }
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((e) =>
          e.title.toLowerCase().contains(q) ||
          (e.group ?? '').toLowerCase().contains(q));
    }
    return items.toList();
  }

  void _selectPlaylist(int i) {
    setState(() {
      selectedPlaylist = i;
      group = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ playback

  Future<void> openItem(MediaItem item) async {
    setState(() => current = item);
    await player.open(Media(item.url));
    await player.play();
  }

  void _playNext() {
    final items = currentItems;
    final c = current;
    if (c == null) return;
    final i = items.indexWhere((e) => e.id == c.id);
    if (i >= 0 && i + 1 < items.length) openItem(items[i + 1]);
  }

  // -------------------------------------------------------------- dialogs

  Future<void> addUrl() async {
    final controller = TextEditingController();
    final titleController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add network stream'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My IPTV channel',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'M3U8 / media URL',
                  hintText: 'https://example.com/live/stream.m3u8',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (result != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;

    final item = MediaItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim().isEmpty
          ? url
          : titleController.text.trim(),
      url: url,
    );

    await _ensurePlaylistAndAdd(item);
    await openItem(item);
  }

  Future<void> importPlaylist() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await FilePicker.platform.readFile(path: file.path!);
    } else {
      return;
    }

    final items = PlaylistService.parseM3u(content);
    if (items.isEmpty) {
      _snack('No playable entries found in this playlist.');
      return;
    }

    final playlistName = file.name
        .replaceFirst(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: playlistName.isEmpty ? 'Imported Playlist' : playlistName,
      items: items,
    );

    final next = [...widget.playlists, playlist];
    await widget.onPlaylistsChanged(next);
    if (mounted) {
      _selectPlaylist(next.length - 1);
      _snack('Imported ${items.length} channels.');
    }
  }

  Future<void> importPlaylistUrl() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import M3U playlist URL'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://example.com/playlist.m3u',
              labelText: 'Playlist URL',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (result != true) return;

    final url = controller.text.trim();
    if (url.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final items = PlaylistService.parseM3u(
        response.body,
        baseUrl: url,
      );

      if (items.isEmpty) throw Exception('No entries found');

      final uri = Uri.tryParse(url);
      final name = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : 'Remote Playlist';

      final playlist = Playlist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.replaceAll(
            RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), ''),
        items: items,
      );

      final next = [...widget.playlists, playlist];
      await widget.onPlaylistsChanged(next);
      if (mounted) {
        _selectPlaylist(next.length - 1);
        _snack('Imported ${items.length} channels.');
      }
    } catch (e) {
      _snack('Playlist import failed: $e');
    }
  }

  Future<void> _ensurePlaylistAndAdd(MediaItem item) async {
    if (widget.playlists.isEmpty) {
      await widget.onPlaylistsChanged([
        Playlist(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'My Playlist',
          items: [item],
        ),
      ]);
      return;
    }

    final p = widget.playlists[_activeIndex];
    final updated = widget.playlists
        .map((x) => x.id == p.id ? x.copyWith(items: [...x.items, item]) : x)
        .toList();
    await widget.onPlaylistsChanged(updated);
  }

  Future<void> removeItem(MediaItem item) async {
    if (widget.playlists.isEmpty) return;
    final p = widget.playlists[_activeIndex];
    final updated = widget.playlists
        .map((x) => x.id == p.id
            ? x.copyWith(items: x.items.where((i) => i.id != item.id).toList())
            : x)
        .toList();
    await widget.onPlaylistsChanged(updated);
    if (current?.id == item.id) {
      await player.stop();
      if (mounted) setState(() => current = null);
    }
  }

  Future<void> createPlaylist() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;

    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: controller.text.trim(),
      items: const [],
    );
    final next = [...widget.playlists, p];
    await widget.onPlaylistsChanged(next);
    if (mounted) _selectPlaylist(next.length - 1);
  }

  // ---------------------------------------------------------------- build

  void _setSearch(String v) {
    if (_searchController.text != v) _searchController.text = v;
    setState(() => search = v);
  }

  Widget _sidebar({required bool inDrawer}) {
    void closeThen(VoidCallback f) {
      if (inDrawer) Navigator.of(context).pop();
      f();
    }

    return _Sidebar(
      playlists: widget.playlists,
      selected: _activeIndex,
      onSelect: (i) => closeThen(() => _selectPlaylist(i)),
      onNew: () => closeThen(createPlaylist),
      onImportFile: () => closeThen(importPlaylist),
      onImportUrl: () => closeThen(importPlaylistUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final items = currentItems;
    final c = current;
    final idx = c == null ? -1 : items.indexWhere((e) => e.id == c.id);
    final VoidCallback? onPrev =
        idx > 0 ? () => openItem(items[idx - 1]) : null;
    final VoidCallback? onNext =
        (idx >= 0 && idx < items.length - 1) ? () => openItem(items[idx + 1]) : null;

    Widget stage(double radius) => _Stage(
          player: player,
          controller: videoController,
          current: c,
          radius: radius,
          onPrevious: onPrev,
          onNext: onNext,
          onImport: importPlaylist,
          onAddUrl: addUrl,
        );

    Widget queue() => _Queue(
          player: player,
          wide: wide,
          title: activePlaylist?.name ?? 'Queue',
          hasPlaylists: widget.playlists.isNotEmpty,
          totalInPlaylist: activePlaylist?.items.length ?? 0,
          items: items,
          groups: groups,
          group: group,
          onGroup: (g) => setState(() => group = g),
          current: c,
          searchController: _searchController,
          search: search,
          onSearch: _setSearch,
          showSearch: !wide,
          onTap: openItem,
          onDelete: removeItem,
          onImport: importPlaylist,
        );

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide
          ? null
          : Drawer(
              width: 300,
              child: SafeArea(child: _sidebar(inDrawer: true)),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide && sidebarOpen)
              SizedBox(width: 272, child: _sidebar(inDrawer: false)),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    wide: wide,
                    controller: _searchController,
                    search: search,
                    onMenu: () => wide
                        ? setState(() => sidebarOpen = !sidebarOpen)
                        : _scaffoldKey.currentState?.openDrawer(),
                    onSearch: _setSearch,
                    onAddUrl: addUrl,
                    onImport: importPlaylist,
                  ),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  child: Column(
                                    children: [
                                      Expanded(child: stage(18)),
                                      _NowPlaying(item: c),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 360, child: queue()),
                            ],
                          )
                        : LayoutBuilder(
                            builder: (context, box) {
                              final h = math.min(
                                box.maxWidth * 9 / 16,
                                box.maxHeight * .55,
                              );
                              return Column(
                                children: [
                                  SizedBox(height: h, child: stage(0)),
                                  _NowPlaying(item: c),
                                  Expanded(child: queue()),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Top bar
// ======================================================================

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DP.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'DP',
            style: TextStyle(
              color: DP.onAccent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Deeprows',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String search;
  final ValueChanged<String> onSearch;
  final String hint;

  const _SearchField({
    required this.controller,
    required this.search,
    required this.onSearch,
    this.hint = 'Search this playlist',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: DP.muted),
          suffixIcon: search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => onSearch(''),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool wide;
  final TextEditingController controller;
  final String search;
  final VoidCallback onMenu;
  final ValueChanged<String> onSearch;
  final VoidCallback onAddUrl;
  final VoidCallback onImport;

  const _TopBar({
    required this.wide,
    required this.controller,
    required this.search,
    required this.onMenu,
    required this.onSearch,
    required this.onAddUrl,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Playlists',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 4),
            const _Logo(),
            if (wide) ...[
              const SizedBox(width: 28),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _SearchField(
                      controller: controller,
                      search: search,
                      onSearch: onSearch,
                      hint: 'Search channels, movies, music',
                    ),
                  ),
                ),
              ),
            ] else
              const Spacer(),
            IconButton(
              tooltip: 'Add stream URL',
              onPressed: onAddUrl,
              icon: const Icon(Icons.link_rounded),
            ),
            if (wide)
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.playlist_add_rounded, size: 20),
                label: const Text('Import playlist'),
              )
            else
              IconButton(
                tooltip: 'Import playlist',
                onPressed: onImport,
                icon: const Icon(Icons.playlist_add_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Sidebar
// ======================================================================

class _Sidebar extends StatelessWidget {
  final List<Playlist> playlists;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew;
  final VoidCallback onImportFile;
  final VoidCallback onImportUrl;

  const _Sidebar({
    required this.playlists,
    required this.selected,
    required this.onSelect,
    required this.onNew,
    required this.onImportFile,
    required this.onImportUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DP.panel,
        border: Border(right: BorderSide(color: DP.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: _Logo(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.upload_file_rounded,
                  label: 'Import M3U file',
                  onTap: onImportFile,
                ),
                _ActionRow(
                  icon: Icons.cloud_download_outlined,
                  label: 'Import M3U URL',
                  onTap: onImportUrl,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                const Text(
                  'Playlists',
                  style: TextStyle(
                    color: DP.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'New playlist',
                  visualDensity: VisualDensity.compact,
                  onPressed: onNew,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: playlists.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'No playlists yet. Import an M3U file or link to create one.',
                      style: TextStyle(color: DP.muted, height: 1.4),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: playlists.length,
                    itemBuilder: (_, i) => _PlaylistTile(
                      playlist: playlists[i],
                      selected: i == selected,
                      onTap: () => onSelect(i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: DP.muted),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final bool selected;
  final VoidCallback onTap;
  const _PlaylistTile({
    required this.playlist,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? DP.accent.withValues(alpha: .14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  size: 20,
                  color: selected ? DP.accent : DP.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? DP.accent : DP.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${playlist.items.length}',
                  style: const TextStyle(color: DP.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Stage (player or empty state) and now playing
// ======================================================================

class _Stage extends StatelessWidget {
  final Player player;
  final VideoController controller;
  final MediaItem? current;
  final double radius;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onImport;
  final VoidCallback onAddUrl;

  const _Stage({
    required this.player,
    required this.controller,
    required this.current,
    required this.radius,
    required this.onPrevious,
    required this.onNext,
    required this.onImport,
    required this.onAddUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = current;
    if (c == null) {
      return Container(
        decoration: BoxDecoration(
          color: DP.panel,
          borderRadius: BorderRadius.circular(radius),
          border: radius == 0 ? null : Border.all(color: DP.line),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: DP.line, width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 40, color: DP.muted),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Nothing playing yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pick something from your playlist, or bring in a new one.',
                    style: TextStyle(color: DP.muted),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.playlist_add_rounded, size: 20),
                        label: const Text('Import playlist'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAddUrl,
                        icon: const Icon(Icons.link_rounded, size: 20),
                        label: const Text('Add stream URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: Colors.black,
        child: PlayerPanel(
          player: player,
          controller: controller,
          mediaId: c.id,
          title: c.title,
          subtitle: c.group,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  final MediaItem? item;
  const _NowPlaying({required this.item});

  @override
  Widget build(BuildContext context) {
    final i = item;
    if (i == null) return const SizedBox(height: 4);
    final host = Uri.tryParse(i.url)?.host ?? '';
    final detail = [
      if (i.group != null && i.group!.isNotEmpty) i.group!,
      if (host.isNotEmpty) host,
    ].join('  ·  ');

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: DP.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Queue
// ======================================================================

class _Queue extends StatelessWidget {
  final Player player;
  final bool wide;
  final String title;
  final bool hasPlaylists;
  final int totalInPlaylist;
  final List<MediaItem> items;
  final List<String> groups;
  final String? group;
  final ValueChanged<String?> onGroup;
  final MediaItem? current;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearch;
  final bool showSearch;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onDelete;
  final VoidCallback onImport;

  const _Queue({
    required this.player,
    required this.wide,
    required this.title,
    required this.hasPlaylists,
    required this.totalInPlaylist,
    required this.items,
    required this.groups,
    required this.group,
    required this.onGroup,
    required this.current,
    required this.searchController,
    required this.search,
    required this.onSearch,
    required this.showSearch,
    required this.onTap,
    required this.onDelete,
    required this.onImport,
  });

  Widget _empty() {
    String message;
    if (!hasPlaylists) {
      message = 'Import an M3U playlist to get started.';
    } else if (search.trim().isNotEmpty) {
      message = 'No matches for "${search.trim()}".';
    } else if (group != null) {
      message = 'Nothing in this group.';
    } else {
      message = 'This playlist is empty.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DP.muted)),
            if (!hasPlaylists) ...[
              const SizedBox(height: 14),
              FilledButton(
                  onPressed: onImport, child: const Text('Import playlist')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DP.panel,
        border: Border(
          left: wide ? const BorderSide(color: DP.line) : BorderSide.none,
          top: wide ? BorderSide.none : const BorderSide(color: DP.line),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                Text(
                  items.length == totalInPlaylist
                      ? '$totalInPlaylist'
                      : '${items.length} of $totalInPlaylist',
                  style: const TextStyle(color: DP.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _SearchField(
                controller: searchController,
                search: search,
                onSearch: onSearch,
              ),
            ),
          if (groups.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                children: [
                  _GroupChip(
                    label: 'All',
                    selected: group == null,
                    onTap: () => onGroup(null),
                  ),
                  for (final g in groups)
                    _GroupChip(
                      label: g,
                      selected: group == g,
                      onTap: () => onGroup(group == g ? null : g),
                    ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? _empty()
                : StreamBuilder<bool>(
                    stream: player.stream.playing,
                    initialData: player.state.playing,
                    builder: (context, snap) {
                      final playing = snap.data ?? false;
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                        itemCount: items.length,
                        itemBuilder: (_, i) => MediaTile(
                          key: ValueKey(items[i].id),
                          item: items[i],
                          selected: current?.id == items[i].id,
                          playing: playing,
                          onTap: () => onTap(items[i]),
                          onDelete: () => onDelete(items[i]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? DP.accent.withValues(alpha: .2) : DP.raised,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? DP.accent : Colors.transparent),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? DP.accent : DP.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
