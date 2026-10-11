import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/tv_focus.dart';

/// A [RangeSlider] that a TV remote can adjust.
///
/// [RangeSlider] has no keyboard support, so on TV the slider is a single
/// focus stop: left and right move the active thumb by one division, Select
/// switches between the two thumbs, and up and down move focus on.
class TVRangeSlider extends StatefulWidget {
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
  State<TVRangeSlider> createState() => _TVRangeSliderState();
}

class _TVRangeSliderState extends State<TVRangeSlider> {
  bool _focused = false;
  bool _adjustingEnd = false;

  double get _step => (widget.max - widget.min) / widget.divisions;

  /// Snaps to a division, so repeated steps do not accumulate rounding error.
  double _snap(double value) =>
      widget.min + ((value - widget.min) / _step).round() * _step;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (tvSelectKeys.contains(key)) {
      if (event is KeyDownEvent) {
        setState(() => _adjustingEnd = !_adjustingEnd);
      }
      return KeyEventResult.handled;
    }
    final direction = tvArrowDirections[key];
    if (direction != TraversalDirection.left &&
        direction != TraversalDirection.right) {
      return KeyEventResult.ignored;
    }
    final delta = direction == TraversalDirection.right ? _step : -_step;
    final values = widget.values;
    // A thumb stops at the other one instead of pushing it.
    final next = _adjustingEnd
        ? RangeValues(
            values.start,
            _snap(values.end + delta).clamp(values.start, widget.max),
          )
        : RangeValues(
            _snap(values.start + delta).clamp(widget.min, values.end),
            values.end,
          );
    if (next != values) {
      widget.onChanged(next);
    }
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      // The hint appears below the slider once focused, so it is scrolled
      // into view after it is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(context, alignment: 0.5);
        }
      });
    }
  }

  Widget _buildSlider() => RangeSlider(
    values: widget.values,
    min: widget.min,
    max: widget.max,
    divisions: widget.divisions,
    labels: widget.labels,
    onChanged: widget.onChanged,
  );

  @override
  Widget build(BuildContext context) {
    if (!isTV()) {
      return _buildSlider();
    }
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Focus(
      onKeyEvent: _onKeyEvent,
      onFocusChange: _onFocusChange,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeFocus(child: _buildSlider()),
          if (_focused)
            Text(
              _adjustingEnd
                  ? '左右调节上限 ${widget.labels.end}，按确认切换到下限'
                  : '左右调节下限 ${widget.labels.start}，按确认切换到上限',
              style: textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
