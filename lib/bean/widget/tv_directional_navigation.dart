import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';

/// Puts [child] in directional navigation mode on TV.
///
/// In that mode a focused [Slider] only adjusts on left and right, so up and
/// down move focus out of it instead of changing the value. The mode is not
/// applied app-wide because it also makes every disabled or decorative
/// [InkWell] focusable.
class TVDirectionalNavigation extends StatelessWidget {
  const TVDirectionalNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isTV()) {
      return child;
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        navigationMode: NavigationMode.directional,
      ),
      child: child,
    );
  }
}
