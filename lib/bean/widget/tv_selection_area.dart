import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';

/// A [SelectionArea] that does not trap the D-pad on TV.
///
/// A focused selection area uses the arrow keys to move its selection, so a
/// remote cannot leave it. On TV, where text cannot be selected anyway, the
/// content is a plain focus stop instead, which still lets the D-pad scroll
/// through it.
class TVSelectionArea extends StatelessWidget {
  const TVSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      isTV() ? Focus(child: child) : SelectionArea(child: child);
}
