import 'package:dp_deeprows_player/services/playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses #EXTINF entries and resolves relative urls', () {
    const m3u = '#EXTM3U\n'
        '#EXTINF:-1 group-title="News" tvg-logo="http://x/l.png",Channel One\n'
        'live/one.m3u8\n';
    final items =
        PlaylistService.parseM3u(m3u, baseUrl: 'https://example.com/a/list.m3u');
    expect(items, hasLength(1));
    expect(items.first.title, 'Channel One');
    expect(items.first.group, 'News');
    expect(items.first.url, 'https://example.com/a/live/one.m3u8');
  });
}
