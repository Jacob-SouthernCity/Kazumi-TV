import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reveals the start or end of a vertical list when focus nears it.
///
/// Focus traversal only scrolls far enough to show the focused control, so
/// content without controls above the first one (headers, statistics) or
/// below the last one never comes back into view on a remote. When the
/// focused control would still be fully visible with the list scrolled to
/// its start, the list scrolls there; the same applies to its end.
class TVScrollEdges extends StatefulWidget {
  const TVScrollEdges({super.key, required this.child});

  final Widget child;

  @override
  State<TVScrollEdges> createState() => _TVScrollEdgesState();
}

class _TVScrollEdgesState extends State<TVScrollEdges> {
  static const Duration _duration = Duration(milliseconds: 200);

  FocusNode? _lastPrimary;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == _lastPrimary) {
      return;
    }
    _lastPrimary = primary;
    // After the traversal has scrolled the control into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (primary == FocusManager.instance.primaryFocus) {
        _alignToEdge(primary);
      }
    });
  }

  void _alignToEdge(FocusNode? node) {
    final nodeContext = node?.context;
    if (node == null || node is FocusScopeNode || nodeContext == null) {
      return;
    }
    // A horizontal row, such as a chip list, sits inside the page's list.
    final scrollable = Scrollable.maybeOf(nodeContext, axis: Axis.vertical);
    final renderObject = nodeContext.findRenderObject();
    if (scrollable == null ||
        renderObject == null ||
        !renderObject.attached ||
        !scrollable.position.hasContentDimensions) {
      return;
    }
    final viewport = _verticalViewportOf(renderObject);
    if (viewport == null) {
      return;
    }
    final position = scrollable.position;
    // Offsets at which the control sits at the bottom or top of the view.
    final atBottom = viewport.getOffsetToReveal(renderObject, 1.0).offset;
    final atTop = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final double target;
    if (atBottom <= position.minScrollExtent) {
      target = position.minScrollExtent;
    } else if (atTop >= position.maxScrollExtent) {
      target = position.maxScrollExtent;
    } else {
      return;
    }
    if ((position.pixels - target).abs() > 0.5) {
      position.animateTo(target, duration: _duration, curve: Curves.easeOut);
    }
  }

  static RenderViewportBase? _verticalViewportOf(RenderObject object) {
    RenderObject? current = object;
    while (current != null) {
      final viewport = RenderAbstractViewport.maybeOf(current);
      if (viewport is! RenderViewportBase) {
        return null;
      }
      if (viewport.axis == Axis.vertical) {
        return viewport;
      }
      current = viewport.parent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
