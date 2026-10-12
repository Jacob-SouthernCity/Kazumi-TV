import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// Returns true when it consumed the Back press.
typedef TVBackHandler = bool Function();

/// Directional focus that can also enter controls inside the focused node.
///
/// Plain traversal only looks beyond the focused node's edges, so it never
/// reaches controls inside it: a container that wraps a page or sheet to
/// receive keyboard shortcuts, or a card whose full-size tap area is layered
/// over its own buttons. When nothing lies beyond the edge, focus moves to
/// the first inner control in the pressed direction.
///
/// Widgets that use the arrows themselves handle them before this action,
/// such as the player, sliders and text fields.
class TVDirectionalFocusAction extends DirectionalFocusAction {
  static Map<Type, Action<Intent>> get appActions => {
    ...WidgetsApp.defaultActions,
    DirectionalFocusIntent: TVDirectionalFocusAction(),
  };

  @override
  void invoke(DirectionalFocusIntent intent) {
    final primary = primaryFocus;
    if (primary == null || primary.focusInDirection(intent.direction)) {
      return;
    }
    final target = _firstInnerNodeInDirection(primary, intent.direction);
    final targetContext = target?.context;
    if (target == null || targetContext == null) {
      return;
    }
    target.requestFocus();
    Scrollable.ensureVisible(targetContext);
  }

  static FocusNode? _firstInnerNodeInDirection(
    FocusNode outer,
    TraversalDirection direction,
  ) {
    final candidates =
        outer.nearestScope?.traversalDescendants ?? outer.traversalDescendants;
    final outerRect = outer.rect;
    FocusNode? best;
    double? bestEdge;
    for (final node in candidates) {
      if (node == outer || node is FocusScopeNode || node.context == null) {
        continue;
      }
      final rect = node.rect;
      final inner =
          node.ancestors.contains(outer) ||
          (outerRect.contains(rect.center) && !outer.ancestors.contains(node));
      if (!inner) {
        continue;
      }
      // The child nearest the side the D-pad enters from.
      final edge = switch (direction) {
        TraversalDirection.down => rect.top,
        TraversalDirection.up => -rect.bottom,
        TraversalDirection.right => rect.left,
        TraversalDirection.left => -rect.right,
      };
      if (bestEdge == null || edge < bestEdge) {
        bestEdge = edge;
        best = node;
      }
    }
    return best;
  }
}

/// App-wide remote control fixes that the focus system does not cover.
///
/// * `unfocus()` can leave focus on the view scope above every route, where
///   the D-pad finds nothing to move to; an arrow press re-enters the visible
///   route.
/// * Back first closes an open menu, then gives registered handlers (such as
///   the player hiding its controls) a chance, before routes pop.
///
/// Back is taken from the system back request rather than the key event:
/// on newer Android versions the request arrives even when the key event was
/// handled. An unclaimed predictive back gesture also ends in that request.
/// This widget must sit above the app's router so it is asked first.
class TVRemoteNavigation extends StatefulWidget {
  const TVRemoteNavigation({super.key, required this.child});

  final Widget child;

  static final List<TVBackHandler> _backHandlers = [];

  static void addBackHandler(TVBackHandler handler) =>
      _backHandlers.add(handler);

  static void removeBackHandler(TVBackHandler handler) =>
      _backHandlers.remove(handler);

  @override
  State<TVRemoteNavigation> createState() => _TVRemoteNavigationState();
}

class _TVRemoteNavigationState extends State<TVRemoteNavigation>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addEarlyKeyEventHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeEarlyKeyEventHandler(_onKeyEvent);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async => _handleBack();

  bool _handleBack() {
    if (_closeFocusedSubmenu()) {
      return true;
    }
    final menuAction = _focusedMenuAction();
    if (menuAction != null) {
      menuAction.invoke(const DismissIntent());
      return true;
    }
    for (final handler in TVRemoteNavigation._backHandlers.reversed) {
      if (handler()) {
        return true;
      }
    }
    return false;
  }

  /// Dismissing closes the whole menu tree, while the closing arrow key
  /// closes only the submenu and refocuses its button, as Back should.
  bool _closeFocusedSubmenu() {
    final primaryContext = FocusManager.instance.primaryFocus?.context;
    if (primaryContext == null ||
        primaryContext.findAncestorWidgetOfExactType<SubmenuButton>() == null ||
        !(MenuController.maybeOf(primaryContext)?.isOpen ?? false)) {
      return false;
    }
    final closing = Directionality.of(primaryContext) == TextDirection.rtl
        ? TraversalDirection.right
        : TraversalDirection.left;
    Actions.maybeInvoke(primaryContext, DirectionalFocusIntent(closing));
    return true;
  }

  DismissMenuAction? _focusedMenuAction() {
    final primaryContext = FocusManager.instance.primaryFocus?.context;
    if (primaryContext == null) {
      return null;
    }
    final action = Actions.maybeFind<DismissIntent>(primaryContext);
    return action is DismissMenuAction &&
            action.isEnabled(const DismissIntent())
        ? action
        : null;
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final direction = tvArrowDirections[event.logicalKey];
    if (event is KeyDownEvent &&
        direction != null &&
        _recoverStrandedFocus(direction)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _recoverStrandedFocus(TraversalDirection direction) {
    final primary = FocusManager.instance.primaryFocus;
    final primaryContext = primary?.context;
    if (primary is! FocusScopeNode ||
        primaryContext == null ||
        ModalRoute.of(primaryContext) != null) {
      return false;
    }
    for (final node in primary.traversalDescendants) {
      final nodeContext = node.context;
      if (node is FocusScopeNode ||
          nodeContext == null ||
          !isOnVisibleRoute(nodeContext)) {
        continue;
      }
      final scope = node.enclosingScope;
      final policy = FocusTraversalGroup.maybeOf(nodeContext);
      if (scope == null || policy is! DirectionalFocusTraversalPolicyMixin) {
        continue;
      }
      // Focused directly: a directional move from the scope would be undone
      // by the policy's reverse-direction history on the next opposite press.
      final target = policy.findFirstFocusInDirection(scope, direction) ?? node;
      target.requestFocus();
      final targetContext = target.context;
      if (targetContext != null) {
        Scrollable.ensureVisible(targetContext);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
