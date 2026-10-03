import '../models/media_item.dart';

class PlaylistService {
  static List<MediaItem> parseM3u(String content, {String? baseUrl}) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final result = <MediaItem>[];

    String? title;
    String? group;
    String? logo;
    String? artist;

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        final comma = line.indexOf(',');
        final metadata = comma >= 0 ? line.substring(0, comma) : line;
        title = comma >= 0 ? line.substring(comma + 1).trim() : 'Untitled';
        group = _attribute(metadata, 'group-title');
        logo = _attribute(metadata, 'tvg-logo');
        artist = _attribute(metadata, 'tvg-name');
        continue;
      }

      if (line.startsWith('#')) continue;

      final url = _resolve(line, baseUrl);
      if (url.isEmpty) continue;

      result.add(
        MediaItem(
          id: '${DateTime.now().microsecondsSinceEpoch}-${result.length}',
          title: title?.isNotEmpty == true ? title! : _nameFromUrl(url),
          url: url,
          group: group,
          logo: logo,
          artist: artist,
        ),
      );

      title = null;
      group = null;
      logo = null;
      artist = null;
    }

    return result;
  }

  static String? _attribute(String line, String key) {
    final pattern = RegExp(
      '${RegExp.escape(key)}\\s*=\\s*"([^"]*)"',
      caseSensitive: false,
    );
    return pattern.firstMatch(line)?.group(1);
  }

  static String _resolve(String value, String? baseUrl) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.hasScheme) return value;
    if (baseUrl == null) return value;
    final base = Uri.tryParse(baseUrl);
    if (base == null) return value;
    return base.resolve(value).toString();
  }

  static String _nameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return last.isEmpty ? url : Uri.decodeComponent(last);
  }
}
