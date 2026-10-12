import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// Keeps the on-screen keyboard closed while the D-pad passes over a text
/// field.
///
/// While the user is not typing, a [_KeyboardGate] is the current text input
/// control, so a focused text field attaches to the platform with
/// [TextInputType.none] and no keyboard appears, not even for a frame.
/// Select on the text field, or a tap, restores the platform control and
/// opens the keyboard. Leaving the field or closing the keyboard installs the
/// gate again.
///
/// When the keyboard closes the text field calls `unfocus()`, so focus is
/// handed back to that field instead of falling to the route scope.
class TVKeyboardGuard extends StatefulWidget {
  const TVKeyboardGuard({super.key, required this.child});

  final Widget child;

  /// Whether the user asked to type into the focused text field.
  static bool get isEditing => _isEditing;
  static bool _isEditing = false;

  @override
  State<TVKeyboardGuard> createState() => _TVKeyboardGuardState();
}

/// A text input control without any UI. While it is current, the platform
/// control is attached with [TextInputType.none], which shows no keyboard.
class _KeyboardGate with TextInputControl {
  /// Whether a text field attached while the gate was current.
  bool attached = false;

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    attached = true;
  }

  @override
  void detach(TextInputClient client) {
    attached = false;
  }
}

class _TVKeyboardGuardState extends State<TVKeyboardGuard>
    with WidgetsBindingObserver {
  final _KeyboardGate _gate = _KeyboardGate();
  FocusNode? _lastPrimary;
  FocusNode? _reattaching;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    TextInput.setInputControl(_gate);
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    FocusManager.instance.addEarlyKeyEventHandler(_onKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  @override
  void dispose() {
    TextInput.restorePlatformInputControl();
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    FocusManager.instance.removeEarlyKeyEventHandler(_onKeyEvent);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    super.dispose();
  }

  void _allowKeyboard() {
    if (TVKeyboardGuard._isEditing) {
      return;
    }
    TVKeyboardGuard._isEditing = true;
    // Read before restoring: the gate receives no detach once it is removed.
    final attachedToGate = _gate.attached;
    _gate.attached = false;
    TextInput.restorePlatformInputControl();
    final primary = FocusManager.instance.primaryFocus;
    if (attachedToGate && primary != null && _isTextField(primary)) {
      _reattach(primary);
    }
  }

  /// The platform applies the keyboard type only when a text field attaches,
  /// so a field that attached with [TextInputType.none] reconnects by losing
  /// and regaining focus, and its keyboard opens.
  void _reattach(FocusNode field) {
    _reattaching = field;
    field.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reattaching = null;
      if (field.context != null && field.canRequestFocus) {
        field.requestFocus();
      }
    });
  }

  void _blockKeyboard() {
    if (!TVKeyboardGuard._isEditing) {
      return;
    }
    TVKeyboardGuard._isEditing = false;
    // Hides an open keyboard; later text fields attach without one.
    TextInput.setInputControl(_gate);
  }

  // Touch and mouse open the keyboard directly, as on phones.
  void _onPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _allowKeyboard();
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
      _blockKeyboard();
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
    if (primary == previous || _reattaching != null) {
      return;
    }

    if (primary is FocusScopeNode && _isTextField(previous)) {
      final previousContext = previous!.context!;
      if (previous.canRequestFocus && isOnVisibleRoute(previousContext)) {
        _blockKeyboard();
        previous.requestFocus();
        return;
      }
    }

    if (!_isTextField(primary)) {
      _blockKeyboard();
    }
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final primary = FocusManager.instance.primaryFocus;
    // The TV keyboard takes the D-pad while it is open, so a remote key
    // press reaching the app means it closed or was never opened. Key ups
    // are skipped: the release of the Select that opened it arrives later.
    final remotePress =
        event is! KeyUpEvent &&
        (tvArrowDirections.containsKey(event.logicalKey) ||
            tvSelectKeys.contains(event.logicalKey));
    if (remotePress && TVKeyboardGuard._isEditing) {
      _blockKeyboard();
    }
    if (!_isTextField(primary)) {
      return KeyEventResult.ignored;
    }
    if (tvSelectKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _allowKeyboard();
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
