import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/status.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/status_viewer_notifier.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  const StatusViewerScreen({super.key, required this.statuses});

  final List<StatusItem> statuses;

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = statusViewerNotifierProvider(widget.statuses);
    final state = ref.watch(provider);
    final myUserId = ref.watch(currentUserIdProvider);

    ref.listen(provider, (prev, next) {
      if (next.finished && mounted) Navigator.of(context).pop();
    });

    final current = state.current;
    if (current == null) return const SizedBox.shrink();
    final isMine = current.userId == myUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            ref.read(provider.notifier).previous();
          } else {
            ref.read(provider.notifier).next();
          }
        },
        onLongPressStart: (_) => ref.read(provider.notifier).pause(),
        onLongPressEnd: (_) => ref.read(provider.notifier).resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _StatusContent(item: current),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: List.generate(state.statuses.length, (i) {
                      final progress = i < state.index ? 1.0 : (i == state.index ? state.progress : 0.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        AppAvatar(photoUrl: current.user?.photoUrl, initials: current.user?.initials ?? '?', size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            current.user?.displayName ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isMine)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton.icon(
                        onPressed: () => context.pushNamed(
                          RouteNames.statusViews,
                          extra: current.id,
                        ),
                        icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                        label: const Text('Viewed by', style: TextStyle(color: Colors.white)),
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

class _StatusContent extends StatelessWidget {
  const _StatusContent({required this.item});

  final StatusItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case StatusType.text:
        final bg = _parseColor(item.backgroundColor) ?? Colors.deepOrange;
        return Container(
          color: bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Text(
            item.content ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        );
      case StatusType.image:
        return item.mediaUrl != null
            ? CachedNetworkImage(imageUrl: item.mediaUrl!, fit: BoxFit.contain)
            : const ColoredBox(color: Colors.black87);
      case StatusType.video:
        return item.mediaUrl != null ? _VideoStatusContent(url: item.mediaUrl!) : const ColoredBox(color: Colors.black87);
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }
}

class _VideoStatusContent extends StatefulWidget {
  const _VideoStatusContent({required this.url});

  final String url;

  @override
  State<_VideoStatusContent> createState() => _VideoStatusContentState();
}

class _VideoStatusContentState extends State<_VideoStatusContent> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
