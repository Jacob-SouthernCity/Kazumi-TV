import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Draws a ring around the focused widget so D-pad users can see focus.
///
/// Focus rects move with scrolling and route or panel animations, so after
/// any key, focus or scroll change the ring is tracked every frame until it
/// has been still for a short while.
class TVFocusHighlight extends StatefulWidget {
  const TVFocusHighlight({super.key, required this.child});

  final Widget child;

  @override
  State<TVFocusHighlight> createState() => _TVFocusHighlightState();
}

class _TVFocusHighlightState extends State<TVFocusHighlight>
    with SingleTickerProviderStateMixin {
  static const int _stillFramesBeforeStop = 30;
  static const double _minHighlightExtent = 8;

  late final Ticker _ticker = createTicker(_onTick);
  final GlobalKey _overlayKey = GlobalKey();
  Rect? _focusRect;
  int _stillFrames = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_track);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_track);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _track();
    return false;
  }

  void _track() {
    _stillFrames = 0;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final rect = _currentFocusRect();
    if (rect == _focusRect) {
      _stillFrames++;
      if (_stillFrames >= _stillFramesBeforeStop) {
        _ticker.stop();
      }
      return;
    }
    _stillFrames = 0;
    setState(() => _focusRect = rect);
  }

  Rect? _currentFocusRect() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null || focus is FocusScopeNode) {
      return null;
    }
    final renderObject = focusContext.findRenderObject();
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        overlayBox == null ||
        !overlayBox.hasSize) {
      return null;
    }
    final size = renderObject.size;
    if (size.width < _minHighlightExtent || size.height < _minHighlightExtent) {
      return null;
    }
    // Large focus nodes wrap whole pages or the player, not a control.
    final overlaySize = overlayBox.size;
    if (size.width >= overlaySize.width * 0.9 &&
        size.height >= overlaySize.height * 0.9) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    return topLeft & size;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _track();
        return false;
      },
      child: Stack(
        key: _overlayKey,
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          if (_focusRect != null)
            Positioned.fromRect(
              rect: _focusRect!.inflate(3),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
