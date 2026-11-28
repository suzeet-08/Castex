import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'castex_core.dart';

class CastexCinemaPlayerScreen extends StatefulWidget {
  final CastexController controller;
  final MediaItem item;
  final EpisodeItem episode;
  final StreamSource stream;
  final List<StreamSource> playlist;

  const CastexCinemaPlayerScreen({
    super.key,
    required this.controller,
    required this.item,
    required this.episode,
    required this.stream,
    this.playlist = const [],
  });

  @override
  State<CastexCinemaPlayerScreen> createState() =>
      _CastexCinemaPlayerScreenState();
}

class _CastexCinemaPlayerScreenState extends State<CastexCinemaPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  final ValueNotifier<Duration> _posNotifier = ValueNotifier(Duration.zero);

  late StreamSource _currentStream;
  bool _initialized = false;
  bool _showControls = true;
  bool _screenLocked = false;
  bool _isFast2x = false;

  double _playbackSpeed = 1.0;
  int _fitMode = 0; // 0 = Fit, 1 = 16:9, 2 = Fill
  double _brightnessLevel = 1.0; // 0.2 to 1.0
  double _volumeLevel = 1.0; // 0.0 to 1.0
  String? _gestureHudText;
  IconData? _gestureHudIcon;
  Timer? _hudTimer;
  Timer? _autoHideTimer;

  String _activeDubLayer = '';
  String _subLang = 'Hinglish';
  double _subOffsetSec = 0.0;
  List<TimedSubtitleCue> _subCues = [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _currentStream = widget.stream;
    _activeDubLayer = widget.stream.dubLayer;
    _subLang = widget.controller.appearance.defaultSubLang;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadSubtitles();
    _initPlayer(_currentStream.url);
  }

  Future<void> _loadSubtitles({String? customSrtUrl}) async {
    if (_subLang == 'Off') {
      setState(() => _subCues = []);
      return;
    }
    final cues = await CastexAddonEngine.fetchKotoSubCues(
      mediaTitle: widget.item.title,
      episodeTitle: widget.episode.title,
      targetLang: _subLang,
      customSrtUrl: customSrtUrl,
    );
    if (mounted) {
      setState(() => _subCues = cues);
    }
  }

  Future<void> _initPlayer(String url, {Duration? resumeAt}) async {
    setState(() {
      _initialized = false;
      _errorText = null;
    });

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoCtrl = ctrl;

    try {
      await ctrl.initialize();
      await ctrl.setPlaybackSpeed(_playbackSpeed);
      await ctrl.setVolume(_volumeLevel);
      if (resumeAt != null && resumeAt > Duration.zero) {
        await ctrl.seekTo(resumeAt);
      }
      ctrl.addListener(_onPlayerTick);
      await ctrl.play();
      if (mounted) {
        setState(() => _initialized = true);
        _restartAutoHide();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Stream error: $e');
      }
    }
  }

  void _onPlayerTick() {
    final ctrl = _videoCtrl;
    if (!mounted || ctrl == null || !ctrl.value.isInitialized) return;

    final pos = ctrl.value.position;
    // Update ValueNotifier only (no full-screen rebuilds -> 120Hz smooth!)
    if ((pos - _posNotifier.value).abs() >= const Duration(milliseconds: 250)) {
      _posNotifier.value = pos;
    }

    final durSec = ctrl.value.duration.inSeconds;
    if (durSec > 0) {
      final frac = pos.inSeconds / durSec;
      if (frac >= 0.80 &&
          !widget.controller.completed80Ids.contains(widget.item.id)) {
        widget.controller.recordWatchProgress(widget.item, frac, 4);
      }
    }
  }

  void _restartAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_screenLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showGestureHud(IconData icon, String label) {
    _hudTimer?.cancel();
    setState(() {
      _gestureHudIcon = icon;
      _gestureHudText = label;
    });
    _hudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _gestureHudIcon = null;
          _gestureHudText = null;
        });
      }
    });
  }

  Future<void> _switchStream(StreamSource next) async {
    final currentPos = _videoCtrl?.value.position ?? Duration.zero;
    _videoCtrl?.removeListener(_onPlayerTick);
    await _videoCtrl?.dispose();
    setState(() {
      _currentStream = next;
      _activeDubLayer = next.dubLayer;
    });
    await _initPlayer(next.url, resumeAt: currentPos);
  }

  Future<void> _exitPlayerCleanly() async {
    _autoHideTimer?.cancel();
    _hudTimer?.cancel();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _hudTimer?.cancel();
    final ctrl = _videoCtrl;
    if (ctrl != null && _initialized && ctrl.value.isInitialized) {
      final dur = ctrl.value.duration.inSeconds;
      final pos = ctrl.value.position.inSeconds;
      if (dur > 0) {
        widget.controller.recordWatchProgress(
          widget.item,
          pos / dur,
          (pos / 60).ceil(),
        );
      }
    }
    ctrl?.removeListener(_onPlayerTick);
    ctrl?.dispose();
    _posNotifier.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _seekRelative(int sec) {
    final ctrl = _videoCtrl;
    if (!_initialized || _screenLocked || ctrl == null) return;
    final target = ctrl.value.position + Duration(seconds: sec);
    ctrl.seekTo(target < Duration.zero ? Duration.zero : target);
    _showGestureHud(
      sec < 0 ? Icons.replay_10_rounded : Icons.forward_10_rounded,
      '${sec > 0 ? '+' : ''}${sec}s',
    );
  }

  void _openCustomSrtDialog() {
    final srtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load External .SRT / .VTT Subtitle URL'),
        content: TextField(
          controller: srtCtrl,
          decoration: const InputDecoration(
            hintText: 'https://...subtitle.srt',
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSubtitles(customSrtUrl: srtCtrl.text);
            },
            child: const Text('Load Subtitles'),
          ),
        ],
      ),
    );
  }

  TimedSubtitleCue? _findActiveCue(Duration pos) {
    if (_subLang == 'Off' || _subCues.isEmpty) return null;
    final adjusted =
        pos + Duration(milliseconds: (_subOffsetSec * 1000).round());
    for (final c in _subCues) {
      if (adjusted >= c.start && adjusted <= c.end) return c;
    }
    // Loop fallback cues smoothly for sample streams
    if (_subCues.length <= 4) {
      final idx = (adjusted.inSeconds.abs() ~/ 6) % _subCues.length;
      return _subCues[idx];
    }
    return null;
  }

  Widget _buildVideoSurface() {
    final ctrl = _videoCtrl;
    if (_errorText != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (!_initialized || ctrl == null) {
      return CircularProgressIndicator(
          color: widget.controller.appearance.accentColor);
    }
    if (_fitMode == 2) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.size.width,
            height: ctrl.value.size.height,
            child: VideoPlayer(ctrl),
          ),
        ),
      );
    }
    final ratio = _fitMode == 1 ? (16 / 9) : ctrl.value.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: VideoPlayer(ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final durSec = (_initialized && _videoCtrl != null)
        ? _videoCtrl!.value.duration.inSeconds
        : 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitPlayerCleanly();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) _restartAutoHide();
          },
          onLongPressStart: (_) {
            if (_initialized && !_screenLocked && _videoCtrl != null) {
              _videoCtrl!.setPlaybackSpeed(2.0);
              setState(() => _isFast2x = true);
            }
          },
          onLongPressEnd: (_) {
            if (_initialized && !_screenLocked && _videoCtrl != null) {
              _videoCtrl!.setPlaybackSpeed(_playbackSpeed);
              setState(() => _isFast2x = false);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Layer
              Center(child: _buildVideoSurface()),

              // Brightness Dimmer Layer (Controlled by Left Vertical Swipe)
              if (_brightnessLevel < 0.99)
                IgnorePointer(
                  child: Container(
                    color: Colors.black
                        .withOpacity((1.0 - _brightnessLevel).clamp(0.0, 0.80)),
                  ),
                ),

              // Left (Brightness + -10s) & Right (Volume + +10s) Gesture Zones
              if (!_screenLocked)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () => _seekRelative(-10),
                        onVerticalDragUpdate: (d) {
                          _brightnessLevel =
                              (_brightnessLevel - d.delta.dy / 220)
                                  .clamp(0.20, 1.0);
                          _showGestureHud(
                            Icons.brightness_6_rounded,
                            'Brightness ${(_brightnessLevel * 100).round()}%',
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () => _seekRelative(10),
                        onVerticalDragUpdate: (d) async {
                          _volumeLevel =
                              (_volumeLevel - d.delta.dy / 220).clamp(0.0, 1.0);
                          await _videoCtrl?.setVolume(_volumeLevel);
                          _showGestureHud(
                            _volumeLevel == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            'Volume ${(_volumeLevel * 100).round()}%',
                          );
                        },
                      ),
                    ),
                  ],
                ),

              // Center Gesture HUD (Brightness / Volume / Seek)
              if (_gestureHudText != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_gestureHudIcon, color: app.accentColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _gestureHudText!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isFast2x)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('2.0x Speed ▶▶',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),

              // KotoSub Live Subtitle Overlay (Driven by ValueListenableBuilder)
              ValueListenableBuilder<Duration>(
                valueListenable: _posNotifier,
                builder: (_, pos, __) {
                  final cue = _findActiveCue(pos);
                  if (cue == null) return const SizedBox.shrink();
                  return Positioned(
                    left: 36,
                    right: 36,
                    bottom: _showControls && !_screenLocked ? 78 : 22,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(app.subBgOpacity),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cue.primaryText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: app.subFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (app.dualSubtitles &&
                                cue.secondaryEnglish.isNotEmpty &&
                                _subLang != 'English')
                              Text(
                                cue.secondaryEnglish,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: app.subFontSize * 0.78,
                                  color: Colors.amberAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Lock Icon when Screen is Locked
              if (_screenLocked)
                Positioned(
                  top: 16,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.lock_rounded,
                        color: Colors.amberAccent, size: 28),
                    onPressed: () {
                      setState(() {
                        _screenLocked = false;
                        _showControls = true;
                      });
                      _restartAutoHide();
                    },
                  ),
                ),

              // Top & Bottom Cinema Controls
              if (_showControls && !_screenLocked) ...[
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: _exitPlayerCleanly,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            Text(
                              '$_activeDubLayer • KotoSub: $_subLang (${_subOffsetSec >= 0 ? '+' : ''}${_subOffsetSec.toStringAsFixed(1)}s) • ${_playbackSpeed}x',
                              style: const TextStyle(
                                  fontSize: 10.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),

                      // Stream / Dub Switcher
                      PopupMenuButton<StreamSource>(
                        onSelected: _switchStream,
                        itemBuilder: (_) {
                          final list = widget.playlist.isNotEmpty
                              ? widget.playlist
                              : [_currentStream];
                          return list
                              .map(
                                (s) => PopupMenuItem<StreamSource>(
                                  value: s,
                                  child: Text(
                                    '${s.dubLayer}: ${s.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.record_voice_over, size: 20),
                        ),
                      ),

                      // KotoSub Language + Sync Offset + External SRT
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == '+0.5') {
                            setState(() => _subOffsetSec += 0.5);
                          } else if (v == '-0.5') {
                            setState(() => _subOffsetSec -= 0.5);
                          } else if (v == 'CUSTOM_SRT') {
                            _openCustomSrtDialog();
                          } else {
                            setState(() => _subLang = v);
                            _loadSubtitles();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'Hinglish',
                              child: Text('KotoSub: Hinglish')),
                          PopupMenuItem(
                              value: 'Bangla', child: Text('KotoSub: বাংলা')),
                          PopupMenuItem(
                              value: 'Banglish',
                              child: Text('KotoSub: Banglish')),
                          PopupMenuItem(
                              value: 'English', child: Text('KotoSub: English')),
                          PopupMenuItem(
                              value: 'Off', child: Text('Subtitles Off')),
                          PopupMenuDivider(),
                          PopupMenuItem(
                              value: '+0.5', child: Text('Sync Offset +0.5s')),
                          PopupMenuItem(
                              value: '-0.5', child: Text('Sync Offset -0.5s')),
                          PopupMenuItem(
                              value: 'CUSTOM_SRT',
                              child: Text('Load .SRT / .VTT URL')),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.subtitles, size: 20),
                        ),
                      ),

                      // Speed Toggle
                      IconButton(
                        icon: const Icon(Icons.speed_rounded, size: 20),
                        onPressed: () async {
                          const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
                          final next = speeds[
                              (speeds.indexOf(_playbackSpeed) + 1) %
                                  speeds.length];
                          setState(() => _playbackSpeed = next);
                          await _videoCtrl?.setPlaybackSpeed(next);
                          _showGestureHud(Icons.speed_rounded, '${next}x');
                        },
                      ),

                      // Aspect Fit Toggle
                      IconButton(
                        icon: const Icon(Icons.aspect_ratio_rounded, size: 20),
                        onPressed: () {
                          setState(() => _fitMode = (_fitMode + 1) % 3);
                          const names = ['Fit', '16:9', 'Fill'];
                          _showGestureHud(
                              Icons.aspect_ratio_rounded, names[_fitMode]);
                        },
                      ),

                      // Screen Lock
                      IconButton(
                        icon: const Icon(Icons.lock_open_rounded, size: 20),
                        onPressed: () => setState(() {
                          _screenLocked = true;
                          _showControls = false;
                        }),
                      ),
                    ],
                  ),
                ),

                // Center Play / Pause / Skip Buttons
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.replay_10_rounded),
                        onPressed: () => _seekRelative(-10),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 54,
                        icon: Icon(
                          _initialized && (_videoCtrl?.value.isPlaying ?? false)
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: app.accentColor,
                        ),
                        onPressed: () {
                          final ctrl = _videoCtrl;
                          if (!_initialized || ctrl == null) return;
                          ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                          setState(() {});
                          _restartAutoHide();
                        },
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.forward_10_rounded),
                        onPressed: () => _seekRelative(10),
                      ),
                    ],
                  ),
                ),

                // Bottom Progress Scrubber (Driven by ValueListenableBuilder)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 12,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _posNotifier,
                    builder: (_, pos, __) {
                      final posSec = pos.inSeconds;
                      return Row(
                        children: [
                          Text(_fmt(pos),
                              style: const TextStyle(fontSize: 11.5)),
                          Expanded(
                            child: Slider(
                              activeColor: app.accentColor,
                              value: posSec
                                  .toDouble()
                                  .clamp(0, math.max(1, durSec).toDouble()),
                              min: 0,
                              max: math.max(1, durSec).toDouble(),
                              onChanged: (v) {
                                _videoCtrl
                                    ?.seekTo(Duration(seconds: v.round()));
                                _restartAutoHide();
                              },
                            ),
                          ),
                          Text(_fmt(Duration(seconds: durSec)),
                              style: const TextStyle(fontSize: 11.5)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
