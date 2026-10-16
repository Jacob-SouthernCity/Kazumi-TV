import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';

/// Makes read-only content, such as a comment, a D-pad stop on TV so the
/// remote can move through it and scroll it into view.
class TVFocusStop extends StatelessWidget {
  const TVFocusStop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => isTV() ? Focus(child: child) : child;
}

/// A [SelectionArea] that does not trap the D-pad on TV.
///
/// A focused selection area uses the arrow keys to move its selection, so a
/// remote cannot leave it. On TV, where text cannot be selected anyway, the
/// content is a [TVFocusStop] instead.
class TVSelectionArea extends StatelessWidget {
  const TVSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      isTV() ? TVFocusStop(child: child) : SelectionArea(child: child);
}
