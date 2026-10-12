import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/side_panel_transition.dart';
import 'package:kazumi/utils/device.dart';

class VideoSidePanel extends StatefulWidget {
  const VideoSidePanel({
    super.key,
    required this.fullscreen,
    required this.child,
    this.disableAnimations = false,
    this.onOpened,
    this.onClosed,
  });

  final bool fullscreen;
  final bool disableAnimations;
  final Widget child;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<VideoSidePanel> createState() => VideoSidePanelState();
}

class VideoSidePanelState extends State<VideoSidePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: SidePanelTransition.duration,
  );
  late final Animation<double> _opacity =
      _animation.drive(CurveTween(curve: Curves.easeIn));

  // Lets the system Back close the open panel instead of leaving the page.
  LocalHistoryEntry? _historyEntry;

  bool get _isOpening =>
      _animation.status == AnimationStatus.forward ||
      _animation.status == AnimationStatus.completed;

  void toggle() {
    if (_isOpening) {
      close();
    } else {
      if (widget.disableAnimations) {
        _animation.value = 1;
      } else {
        _animation.forward();
      }
      _addHistoryEntry();
      widget.onOpened?.call();
    }
  }

  void close() {
    final entry = _historyEntry;
    if (entry != null) {
      // Hides the panel through onRemove.
      entry.remove();
    } else {
      _hide();
    }
  }

  void _hide() {
    if (widget.disableAnimations) {
      _animation.value = 0;
    } else {
      _animation.reverse();
    }
    widget.onClosed?.call();
  }

  void _addHistoryEntry() {
    if (_historyEntry != null) return;
    final entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (_historyEntry == null) return;
        _historyEntry = null;
        _hide();
      },
    );
    _historyEntry = entry;
    ModalRoute.of(context)?.addLocalHistoryEntry(entry);
  }

  void _dropHistoryEntry() {
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
  }

  @override
  void didUpdateWidget(VideoSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset before rendering the new mode to avoid a sidebar flash.
    if (oldWidget.fullscreen != widget.fullscreen) {
      final wasOpen = !_animation.isDismissed;
      _dropHistoryEntry();
      _animation.value = 0;
      // Focus may be inside the removed panel content.
      if (wasOpen) widget.onClosed?.call();
    }
  }

  @override
  void dispose() {
    // Cleared first, so onRemove does not animate a disposed panel.
    _dropHistoryEntry();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (_animation.isDismissed) return const SizedBox.shrink();
            return Stack(
              alignment: Alignment.centerRight,
              children: [
                FadeTransition(
                  opacity: _opacity,
                  child: GestureDetector(
                    onTap: close,
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SidePanelTransition(animation: _animation, child: child!),
              ],
            );
          },
          child: SizedBox(
            // Keep space outside the panel for dismissal.
            width: math.min(constraints.maxWidth * 0.9,
                (constraints.maxWidth / 3).clamp(320.0, 420.0)),
            height: constraints.maxHeight,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(28),
                bottomStart: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              // Consume the hidden status-bar inset for the entire overlay.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeLeft: true,
                // A fresh scope per opening lets the panel content autofocus,
                // so the remote starts inside the panel.
                child: SafeArea(
                  child: isTV()
                      ? FocusScope(child: widget.child)
                      : widget.child,
                ),
              ),
            ),
          ),
        ),
      );
}
