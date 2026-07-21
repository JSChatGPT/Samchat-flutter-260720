import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({super.key, required this.url, required this.iconColor, required this.trackColor});

  final String url;
  final Color iconColor;
  final Color trackColor;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_loaded) {
      await _player.setUrl(widget.url);
      _loaded = true;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    size: 34, color: widget.iconColor);
              },
            ),
            onPressed: _toggle,
          ),
          Expanded(
            child: StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, durationSnap) {
                final duration = durationSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final progress = duration.inMilliseconds == 0
                        ? 0.0
                        : (pos.inMilliseconds / duration.inMilliseconds).clamp(0, 1).toDouble();
                    return SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: widget.iconColor,
                        thumbColor: widget.iconColor,
                        inactiveTrackColor: widget.trackColor,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (v) {
                          if (duration.inMilliseconds > 0) {
                            _player.seek(Duration(milliseconds: (v * duration.inMilliseconds).round()));
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
