import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_remote_navigation.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// Remote handling shared by the TV sliders.
///
/// A focused control is idle: every arrow moves focus, so a slider never
/// traps the D-pad. Select starts adjusting the first of [modes] (such as the
/// lower thumb of a range), Select again moves to the next mode and finally
/// finishes. While adjusting, left and right call [onAdjust]; up, down, Back
/// and leaving the control finish adjusting.
class TVAdjustable extends StatefulWidget {
  const TVAdjustable({
    super.key,
    required this.modes,
    required this.onAdjust,
    required this.adjustingHint,
    required this.child,
  });

  final int modes;

  /// Called with the active mode and a step of 1 or -1.
  final void Function(int mode, int step) onAdjust;

  /// The hint shown while adjusting [mode].
  final String Function(int mode) adjustingHint;
  final Widget child;

  static final Set<FocusNode> _adjusting = {};

  /// Whether [node] belongs to a control that is adjusting, so left and right
  /// must reach it instead of moving focus.
  static bool isAdjusting(FocusNode node) => _adjusting.contains(node);

  @override
  State<TVAdjustable> createState() => _TVAdjustableState();
}

class _TVAdjustableState extends State<TVAdjustable> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  int? _mode;

  @override
  void dispose() {
    TVRemoteNavigation.removeBackHandler(_finishOnBack);
    TVAdjustable._adjusting.remove(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  void _setMode(int? mode) {
    if (mode == _mode) {
      return;
    }
    if (_mode == null) {
      TVRemoteNavigation.addBackHandler(_finishOnBack);
      TVAdjustable._adjusting.add(_focusNode);
    } else if (mode == null) {
      TVRemoteNavigation.removeBackHandler(_finishOnBack);
      TVAdjustable._adjusting.remove(_focusNode);
    }
    setState(() => _mode = mode);
  }

  bool _finishOnBack() {
    _setMode(null);
    return true;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final mode = _mode;
    if (tvSelectKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent) {
        final next = (mode ?? -1) + 1;
        _setMode(next < widget.modes ? next : null);
      }
      return KeyEventResult.handled;
    }
    final direction = tvArrowDirections[event.logicalKey];
    if (mode == null || direction == null) {
      return KeyEventResult.ignored;
    }
    switch (direction) {
      case TraversalDirection.left:
        widget.onAdjust(mode, -1);
        return KeyEventResult.handled;
      case TraversalDirection.right:
        widget.onAdjust(mode, 1);
        return KeyEventResult.handled;
      case TraversalDirection.up:
      case TraversalDirection.down:
        _setMode(null);
        return KeyEventResult.ignored;
    }
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (!focused) {
      _setMode(null);
      return;
    }
    // The hint appears below the control once focused, so it is scrolled
    // into view after it is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(context, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _mode;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      onFocusChange: _onFocusChange,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeFocus(child: widget.child),
          if (_focused)
            Text(
              mode == null ? '按确认键开始调节' : widget.adjustingHint(mode),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: mode == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// The step a remote press moves a slider: one division, or a twentieth of
/// the range for continuous sliders.
double _step(double min, double max, int? divisions) =>
    (max - min) / (divisions ?? 20);

/// Snaps to a step, so repeated presses do not accumulate rounding error.
double _snap(double value, double min, double step) =>
    min + ((value - min) / step).round() * step;

/// A [Slider] that a TV remote adjusts after Select; see [TVAdjustable].
class TVSlider extends StatelessWidget {
  const TVSlider({super.key, required this.slider});

  final Slider slider;

  @override
  Widget build(BuildContext context) {
    final onChanged = slider.onChanged;
    if (!isTV() || onChanged == null) {
      return slider;
    }
    final step = _step(slider.min, slider.max, slider.divisions);
    return TVAdjustable(
      modes: 1,
      adjustingHint: (_) => '左右调节，按确认或返回完成',
      onAdjust: (_, direction) {
        final next = _snap(
          slider.value + direction * step,
          slider.min,
          step,
        ).clamp(slider.min, slider.max);
        if (next != slider.value) {
          onChanged(next);
        }
      },
      child: slider,
    );
  }
}

/// A [RangeSlider] that a TV remote adjusts after Select; see [TVAdjustable].
/// The first mode moves the lower thumb and the second the upper thumb.
class TVRangeSlider extends StatelessWidget {
  const TVRangeSlider({
    super.key,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.labels,
    required this.onChanged,
  });

  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final RangeLabels labels;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final slider = RangeSlider(
      values: values,
      min: min,
      max: max,
      divisions: divisions,
      labels: labels,
      onChanged: onChanged,
    );
    if (!isTV()) {
      return slider;
    }
    final step = _step(min, max, divisions);
    return TVAdjustable(
      modes: 2,
      adjustingHint: (mode) => mode == 0
          ? '左右调节下限 ${labels.start}，按确认切换到上限'
          : '左右调节上限 ${labels.end}，按确认完成',
      onAdjust: (mode, direction) {
        final delta = direction * step;
        // A thumb stops at the other one instead of pushing it.
        final next = mode == 0
            ? RangeValues(
                _snap(values.start + delta, min, step).clamp(min, values.end),
                values.end,
              )
            : RangeValues(
                values.start,
                _snap(values.end + delta, min, step).clamp(values.start, max),
              );
        if (next != values) {
          onChanged(next);
        }
      },
      child: slider,
    );
  }
}
