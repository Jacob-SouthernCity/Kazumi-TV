import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// Keeps the on-screen keyboard closed while the D-pad passes over a text
/// field.
///
/// A focused text field only opens the keyboard after Select; until then the
/// arrow keys keep moving focus. Touch or mouse input opens it directly, as
/// on phones. When the keyboard closes, the text field calls `unfocus()`, so
/// focus is handed back to that field instead of falling to the route scope.
class TVKeyboardGuard extends StatefulWidget {
  const TVKeyboardGuard({super.key, required this.child});

  final Widget child;

  /// Whether the user asked to type into the focused text field.
  static bool get isEditing => _isEditing;
  static bool _isEditing = false;

  @override
  State<TVKeyboardGuard> createState() => _TVKeyboardGuardState();
}

class _TVKeyboardGuardState extends State<TVKeyboardGuard>
    with WidgetsBindingObserver {
  static const Duration _pointerFocusWindow = Duration(milliseconds: 500);

  FocusNode? _lastPrimary;
  bool _keyboardVisible = false;
  DateTime? _lastPointerDown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    FocusManager.instance.addEarlyKeyEventHandler(_onKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    FocusManager.instance.removeEarlyKeyEventHandler(_onKeyEvent);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    super.dispose();
  }

  void _onPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _lastPointerDown = DateTime.now();
    }
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return;
    }
    final visible = views.first.viewInsets.bottom > 0;
    if (_keyboardVisible && !visible) {
      TVKeyboardGuard._isEditing = false;
    }
    _keyboardVisible = visible;
  }

  bool _isTextField(FocusNode? node) {
    final nodeContext = node?.context;
    return nodeContext != null && isInEditableText(nodeContext);
  }

  void _onFocusChanged() {
    final primary = FocusManager.instance.primaryFocus;
    final previous = _lastPrimary;
    _lastPrimary = primary;
    if (primary == previous) {
      return;
    }

    if (primary is FocusScopeNode && _isTextField(previous)) {
      final previousContext = previous!.context!;
      if (previous.canRequestFocus && isOnVisibleRoute(previousContext)) {
        TVKeyboardGuard._isEditing = false;
        previous.requestFocus();
        return;
      }
    }

    if (!_isTextField(primary)) {
      TVKeyboardGuard._isEditing = false;
      return;
    }
    final pointerDown = _lastPointerDown;
    if (pointerDown != null &&
        DateTime.now().difference(pointerDown) < _pointerFocusWindow) {
      TVKeyboardGuard._isEditing = true;
    }
    if (!TVKeyboardGuard._isEditing) {
      // The text field shows the keyboard while handling the same focus
      // change, so hiding has to wait until after it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!TVKeyboardGuard._isEditing &&
            _isTextField(FocusManager.instance.primaryFocus)) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        }
      });
    }
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final primary = FocusManager.instance.primaryFocus;
    if (!_isTextField(primary)) {
      return KeyEventResult.ignored;
    }
    // The TV keyboard floats without changing the view insets and takes the
    // D-pad while it is open, so an arrow reaching the app means it closed.
    if (TVKeyboardGuard._isEditing &&
        tvArrowDirections.containsKey(event.logicalKey)) {
      TVKeyboardGuard._isEditing = false;
    }
    if (TVKeyboardGuard._isEditing) {
      return KeyEventResult.ignored;
    }
    if (tvSelectKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent) {
        TVKeyboardGuard._isEditing = true;
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
      return KeyEventResult.handled;
    }
    final direction = tvArrowDirections[event.logicalKey];
    if (direction != null && event is! KeyUpEvent) {
      // Ignored at the edge of the scope, so TVFocusEscape can still move
      // focus out of a nested navigator.
      return primary!.focusInDirection(direction)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
