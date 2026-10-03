# DP Deeprows Player

A modern VLC-style cross-platform media player built with Flutter.

## Features

- M3U / M3U8 playlist import
- Remote M3U playlist URL import
- M3U8/HLS network playback
- Audio and video playback
- Local media support through URL/file paths
- Search playlist
- Multiple playlists
- Persistent playlists
- Playback speed
- Volume/mute
- Seek bar
- Dark Material 3 UI with a custom design system (lib/theme/app_theme.dart)
- Custom player controls: buffered seek bar, skip +/-10s, prev/next, volume slider, speed, working fullscreen, LIVE badge
- Keyboard shortcuts: Space, Left/Right, Up/Down, M, F, Esc
- Touch gestures: double-tap left/right to seek, double-tap centre for fullscreen
- Group filter chips, auto-play next, playlist drawer on mobile
- Responsive desktop/mobile layout
- Native media engine through media_kit

## Requirements

Use a current Flutter stable release with Dart 3.10+.

## Create platform folders

This repository intentionally keeps the Flutter source small and lets Flutter generate platform boilerplate:

```bash
flutter create .
```

Then install dependencies:

```bash
flutter pub get
```

Run:

```bash
flutter run
```

Desktop examples:

```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

Android:

```bash
flutter run -d android
```

## Build

Windows:

```bash
flutter build windows
```

Android APK:

```bash
flutter build apk --release
```

Android App Bundle:

```bash
flutter build appbundle --release
```

Linux:

```bash
flutter build linux --release
```

macOS:

```bash
flutter build macos --release
```

## Example M3U

```m3u
#EXTM3U
#EXTINF:-1 tvg-id="demo" tvg-name="Demo Channel" group-title="Demo",Demo Channel
https://example.com/live/stream.m3u8
```

Only use streams and playlists you are authorized to access.

## Notes

M3U parsing supports common `#EXTINF` metadata such as:

- `tvg-name`
- `tvg-logo`
- `group-title`

Relative playlist URLs are resolved against the playlist URL when importing a remote M3U file.

## Project

Product name: DP Deeprows Player

Suggested GitHub repository name:

`dp-deeprows-player`

License: MIT
