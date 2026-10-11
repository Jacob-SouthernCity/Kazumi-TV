import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_keyboard_guard.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// Lets D-pad focus leave [child] when it reaches the edge of [child].
///
/// Directional traversal never leaves the nearest focus scope, so focus in a
/// nested navigator cannot reach controls beside it, such as a navigation
/// rail. When the scope has nothing further in the pressed direction, focus
/// moves to the nearest focusable node outside [child].
///
/// This runs as an early key handler because widgets such as menu anchors
/// consume arrow keys even when they cannot move focus.
class TVFocusEscape extends StatefulWidget {
  const TVFocusEscape({super.key, required this.child});

  final Widget child;

  @override
  State<TVFocusEscape> createState() => _TVFocusEscapeState();
}

class _TVFocusEscapeState extends State<TVFocusEscape> {
  static final Set<FocusNode> _boundaries = {};

  final FocusNode _boundary = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );

  @override
  void initState() {
    super.initState();
    _boundaries.add(_boundary);
    FocusManager.instance.addEarlyKeyEventHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKeyEvent);
    _boundaries.remove(_boundary);
    _boundary.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final direction = tvArrowDirections[event.logicalKey];
    final primary = FocusManager.instance.primaryFocus;
    final primaryContext = primary?.context;
    if (event is KeyUpEvent ||
        direction == null ||
        primary == null ||
        primary is FocusScopeNode ||
        primary.skipTraversal ||
        primaryContext == null ||
        !_isInnermostBoundaryOf(primary) ||
        (TVKeyboardGuard.isEditing && isInEditableText(primaryContext)) ||
        (_isHorizontal(direction) && _isInSlider(primaryContext))) {
      return KeyEventResult.ignored;
    }
    final scope = primary.nearestScope;
    if (scope == null || _hasCandidate(scope, primary, direction)) {
      return KeyEventResult.ignored;
    }
    final target = _nearestOutside(primary.rect, direction);
    if (target == null) {
      return KeyEventResult.ignored;
    }
    target.requestFocus();
    return KeyEventResult.handled;
  }

  bool _isInnermostBoundaryOf(FocusNode node) {
    for (final ancestor in node.ancestors) {
      if (_boundaries.contains(ancestor)) {
        return ancestor == _boundary;
      }
    }
    return false;
  }

  static bool _isHorizontal(TraversalDirection direction) =>
      direction == TraversalDirection.left ||
      direction == TraversalDirection.right;

  static bool _isInSlider(BuildContext context) =>
      context.findAncestorWidgetOfExactType<Slider>() != null ||
      context.findAncestorWidgetOfExactType<RangeSlider>() != null;

  /// Mirrors the directional policy's candidate filter, which compares
  /// candidate centers with the current node's edges.
  static bool _isInDirection(Rect from, Rect rect, TraversalDirection d) =>
      switch (d) {
        TraversalDirection.left => rect.center.dx <= from.left,
        TraversalDirection.right => rect.center.dx >= from.right,
        TraversalDirection.up => rect.center.dy <= from.top,
        TraversalDirection.down => rect.center.dy >= from.bottom,
      };

  bool _hasCandidate(
    FocusScopeNode scope,
    FocusNode primary,
    TraversalDirection direction,
  ) {
    final from = primary.rect;
    for (final node in scope.traversalDescendants) {
      if (node == primary || node is FocusScopeNode || node.context == null) {
        continue;
      }
      if (_isInDirection(from, node.rect, direction)) {
        return true;
      }
    }
    return false;
  }

  FocusNode? _nearestOutside(Rect from, TraversalDirection direction) {
    final scope = FocusScope.of(context);
    FocusNode? best;
    var bestScore = double.infinity;
    for (final node in scope.traversalDescendants) {
      final nodeContext = node.context;
      if (node is FocusScopeNode ||
          nodeContext == null ||
          node.ancestors.contains(_boundary) ||
          !isOnVisibleRoute(nodeContext)) {
        continue;
      }
      final rect = node.rect;
      if (!_isInDirection(from, rect, direction)) {
        continue;
      }
      final double gap;
      final double offAxis;
      if (_isHorizontal(direction)) {
        gap = (direction == TraversalDirection.left
                ? from.left - rect.right
                : rect.left - from.right)
            .abs();
        offAxis = (rect.center.dy - from.center.dy).abs();
      } else {
        // Up and down stay in the same column instead of jumping sideways.
        if (rect.right <= from.left || rect.left >= from.right) {
          continue;
        }
        gap = (direction == TraversalDirection.up
                ? from.top - rect.bottom
                : rect.top - from.bottom)
            .abs();
        offAxis = (rect.center.dx - from.center.dx).abs();
      }
      final score = gap + offAxis * 2;
      if (score < bestScore) {
        bestScore = score;
        best = node;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _boundary,
        child: widget.child,
      );
}
