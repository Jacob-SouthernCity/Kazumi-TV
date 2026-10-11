import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final Map<LogicalKeyboardKey, TraversalDirection> tvArrowDirections = {
  LogicalKeyboardKey.arrowUp: TraversalDirection.up,
  LogicalKeyboardKey.arrowDown: TraversalDirection.down,
  LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
  LogicalKeyboardKey.arrowRight: TraversalDirection.right,
};

final Set<LogicalKeyboardKey> tvSelectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

bool isInEditableText(BuildContext context) =>
    context.widget is EditableText ||
    context.findAncestorWidgetOfExactType<EditableText>() != null;

/// Whether every route enclosing [context], nested navigators included, is
/// the current route of its navigator.
bool isOnVisibleRoute(BuildContext context) {
  var route = ModalRoute.of(context);
  if (route == null) {
    return false;
  }
  while (route != null) {
    if (!route.isCurrent) {
      return false;
    }
    final navigatorContext = route.navigator?.context;
    route = navigatorContext == null || !navigatorContext.mounted
        ? null
        : ModalRoute.of(navigatorContext);
  }
  return true;
}
