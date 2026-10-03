import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../theme/app_theme.dart';

/// Video surface with fully custom controls.
///
/// The controls are built through [Video.controls] so they live inside the
/// video's own widget tree. That is what makes fullscreen keep the same UI.
class PlayerPanel extends StatelessWidget {
  final Player player;
  final VideoController controller;
  final String mediaId;
  final String title;
  final String? subtitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.controller,
    required this.mediaId,
    required this.title,
    this.subtitle,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: controller,
      controls: (state) => _Controls(
        state: state,
        player: player,
        mediaId: mediaId,
        title: title,
        subtitle: subtitle,
        onPrevious: onPrevious,
        onNext: onNext,
      ),
    );
  }
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Controls extends StatefulWidget {
  final VideoState state;
  final Player player;
  final String mediaId;
  final String title;
  final String? subtitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Controls({
    required this.state,
    required this.player,
    required this.mediaId,
    required this.title,
    required this.subtitle,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  final FocusNode _focus = FocusNode();
  Timer? _hideTimer;
  StreamSubscription<String>? _errorSub;
  bool _visible = true;
  String? _error;
  Offset _lastTap = Offset.zero;
  double _volumeBeforeMute = 100;

  Player get player => widget.player;

  bool get _touch =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _errorSub = player.stream.error.listen((e) {
      if (mounted && e.isNotEmpty) setState(() => _error = e);
    });
    _armHideTimer();
  }

  @override
  void didUpdateWidget(covariant _Controls old) {
    super.didUpdateWidget(old);
    if (old.mediaId != widget.mediaId) {
      _error = null;
      _show();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _errorSub?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && player.state.playing) setState(() => _visible = false);
    });
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _armHideTimer();
  }

  bool _isLive() =>
      player.state.duration == Duration.zero &&
      player.state.position >= const Duration(seconds: 2);

  void _seekBy(int seconds) {
    if (_isLive()) return;
    final total = player.state.duration;
    var target = player.state.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    player.seek(target);
  }

  void _setVolume(double v) => player.setVolume(v.clamp(0.0, 100.0));

  void _toggleMute() {
    final v = player.state.volume;
    if (v > 0) {
      _volumeBeforeMute = v;
      player.setVolume(0);
    } else {
      player.setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      player.playOrPause();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-10);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _seekBy(10);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _setVolume(player.state.volume + 5);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _setVolume(player.state.volume - 5);
    } else if (k == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (k == LogicalKeyboardKey.keyF) {
      widget.state.toggleFullscreen();
    } else if (k == LogicalKeyboardKey.escape) {
      if (!widget.state.isFullscreen()) return KeyEventResult.ignored;
      widget.state.exitFullscreen();
    } else {
      return KeyEventResult.ignored;
    }
    _show();
    return KeyEventResult.handled;
  }

  void _onTap() {
    _focus.requestFocus();
    if (_touch) {
      if (_visible) {
        setState(() => _visible = false);
      } else {
        _show();
      }
    } else {
      player.playOrPause();
      _show();
    }
  }

  void _onDoubleTap(double width) {
    final x = _lastTap.dx;
    if (x < width * 0.33) {
      _seekBy(-10);
    } else if (x > width * 0.67) {
      _seekBy(10);
    } else {
      widget.state.toggleFullscreen();
    }
    _show();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        final show = _visible || !playing;

        return LayoutBuilder(
          builder: (context, box) {
            return Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: MouseRegion(
                cursor: show ? SystemMouseCursors.basic : SystemMouseCursors.none,
                onHover: (_) => _show(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  onDoubleTapDown: (d) => _lastTap = d.localPosition,
                  onDoubleTap: () => _onDoubleTap(box.maxWidth),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Status(player: player, error: _error),
                      AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !show,
                          child: _Overlay(
                            width: box.maxWidth,
                            player: player,
                            title: widget.title,
                            subtitle: widget.subtitle,
                            fullscreen: widget.state.isFullscreen(),
                            onExitFullscreen: widget.state.exitFullscreen,
                            onToggleFullscreen: widget.state.toggleFullscreen,
                            onPrevious: widget.onPrevious,
                            onNext: widget.onNext,
                            onSeekBy: _seekBy,
                            onToggleMute: _toggleMute,
                            onVolume: _setVolume,
                            onInteract: _show,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Buffering spinner and playback error, shown regardless of control state.
class _Status extends StatelessWidget {
  final Player player;
  final String? error;
  const _Status({required this.player, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: DP.live),
              const SizedBox(height: 12),
              const Text(
                "This stream can't be played",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DP.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (_, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return const Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _Overlay extends StatelessWidget {
  final double width;
  final Player player;
  final String title;
  final String? subtitle;
  final bool fullscreen;
  final VoidCallback onExitFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onSeekBy;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final VoidCallback onInteract;

  const _Overlay({
    required this.width,
    required this.player,
    required this.title,
    required this.subtitle,
    required this.fullscreen,
    required this.onExitFullscreen,
    required this.onToggleFullscreen,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekBy,
    required this.onToggleMute,
    required this.onVolume,
    required this.onInteract,
  });

  @override
  Widget build(BuildContext context) {
    final compact = width < 480;
    final showVolumeSlider = width >= 680;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .7),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 28),
            child: Row(
              children: [
                if (fullscreen)
                  IconButton(
                    tooltip: 'Exit fullscreen',
                    onPressed: onExitFullscreen,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: .65),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _LiveBuilder(
                  player: player,
                  builder: (_, live) =>
                      live ? const _LivePill() : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: .88),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 36, 14, 10),
            child: _LiveBuilder(
              player: player,
              builder: (context, live) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live)
                    const SizedBox(height: 8)
                  else
                    _SeekBar(player: player, onInteract: onInteract),
                  Row(
                    children: [
                      _RoundButton(
                        icon: Icons.skip_previous_rounded,
                        tooltip: 'Previous',
                        onPressed: onPrevious,
                      ),
                      if (!live)
                        _RoundButton(
                          icon: Icons.replay_10_rounded,
                          tooltip: 'Back 10 seconds',
                          onPressed: () => onSeekBy(-10),
                        ),
                      _PlayButton(player: player),
                      if (!live)
                        _RoundButton(
                          icon: Icons.forward_10_rounded,
                          tooltip: 'Forward 10 seconds',
                          onPressed: () => onSeekBy(10),
                        ),
                      _RoundButton(
                        icon: Icons.skip_next_rounded,
                        tooltip: 'Next',
                        onPressed: onNext,
                      ),
                      const Spacer(),
                      if (!compact)
                        _VolumeControl(
                          player: player,
                          showSlider: showVolumeSlider,
                          onToggleMute: onToggleMute,
                          onVolume: onVolume,
                        ),
                      _SpeedMenu(player: player),
                      _RoundButton(
                        icon: fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                        onPressed: onToggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rebuilds with `live == true` for streams that report no duration.
class _LiveBuilder extends StatelessWidget {
  final Player player;
  final Widget Function(BuildContext context, bool live) builder;
  const _LiveBuilder({required this.player, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, d) => StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, p) {
          final live = (d.data ?? Duration.zero) == Duration.zero &&
              (p.data ?? Duration.zero) >= const Duration(seconds: 2);
          return builder(context, live);
        },
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DP.live,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final Player player;
  final VoidCallback onInteract;
  const _SeekBar({required this.player, required this.onInteract});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    const timeStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, pos) => StreamBuilder<Duration>(
        stream: player.stream.duration,
        initialData: player.state.duration,
        builder: (context, dur) => StreamBuilder<Duration>(
          stream: player.stream.buffer,
          initialData: player.state.buffer,
          builder: (context, buf) {
            final position = pos.data ?? Duration.zero;
            final total = dur.data ?? Duration.zero;
            final enabled = total > Duration.zero;
            final totalMs = enabled ? total.inMilliseconds.toDouble() : 1.0;
            final posMs = (_drag ?? position.inMilliseconds.toDouble())
                .clamp(0.0, totalMs)
                .toDouble();
            final bufMs = (buf.data ?? Duration.zero)
                .inMilliseconds
                .toDouble()
                .clamp(0.0, totalMs)
                .toDouble();

            return Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(_fmt(Duration(milliseconds: posMs.round())),
                      style: timeStyle),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: DP.accent,
                      inactiveTrackColor: Colors.white24,
                      secondaryActiveTrackColor: Colors.white38,
                      thumbColor: Colors.white,
                      overlayColor: DP.accent.withValues(alpha: .18),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: posMs,
                      min: 0,
                      max: totalMs,
                      secondaryTrackValue: bufMs,
                      onChangeStart: enabled
                          ? (v) => setState(() => _drag = v)
                          : null,
                      onChanged:
                          enabled ? (v) => setState(() => _drag = v) : null,
                      onChangeEnd: enabled
                          ? (v) {
                              player.seek(Duration(milliseconds: v.round()));
                              setState(() => _drag = null);
                              widget.onInteract();
                            }
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(_fmt(total),
                      textAlign: TextAlign.right, style: timeStyle),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      color: Colors.white,
      disabledColor: Colors.white24,
      icon: Icon(icon),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final Player player;
  const _PlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return Tooltip(
          message: playing ? 'Pause' : 'Play',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: player.playOrPause,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VolumeControl extends StatelessWidget {
  final Player player;
  final bool showSlider;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;

  const _VolumeControl({
    required this.player,
    required this.showSlider,
    required this.onToggleMute,
    required this.onVolume,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snap) {
        final v = (snap.data ?? 100).clamp(0.0, 100.0).toDouble();
        final icon = v == 0
            ? Icons.volume_off_rounded
            : v < 50
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundButton(
              icon: icon,
              tooltip: v == 0 ? 'Unmute' : 'Mute',
              onPressed: onToggleMute,
            ),
            if (showSlider)
              SizedBox(
                width: 96,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: v,
                    min: 0,
                    max: 100,
                    onChanged: onVolume,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  final Player player;
  const _SpeedMenu({required this.player});

  static const _rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String _label(double v) => '${v == v.roundToDouble() ? v.toInt() : v}x';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (context, snap) {
        final rate = snap.data ?? 1.0;
        return PopupMenuButton<double>(
          tooltip: 'Playback speed',
          initialValue: rate,
          onSelected: player.setRate,
          itemBuilder: (_) => [
            for (final v in _rates)
              PopupMenuItem<double>(value: v, child: Text(_label(v))),
          ],
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label(rate),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
