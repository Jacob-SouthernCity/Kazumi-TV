import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';

typedef KazumiMenuBuilder =
    Widget Function(BuildContext context, VoidCallback? toggle);

const _menuItemStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(144, 48)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
  alignment: AlignmentDirectional.centerStart,
  visualDensity: VisualDensity.standard,
);

class KazumiMenuButton extends StatelessWidget {
  const KazumiMenuButton({
    super.key,
    required this.builder,
    required this.menuChildren,
    this.controller,
    this.enabled = true,
    this.animated = false,
    this.crossAxisUnconstrained = true,
    this.onOpen,
    this.onClose,
    this.style,
  });

  final KazumiMenuBuilder builder;
  final List<Widget> menuChildren;
  final MenuController? controller;
  final bool enabled;

  /// Opt in only for menus that previously animated.
  final bool animated;
  final bool crossAxisUnconstrained;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuStyle? style;

  /// Opening a menu leaves focus on its anchor, so on TV one top level item
  /// takes focus: the selected one, or else the first enabled item. Items in
  /// submenus are left alone, or focusing a submenu button would pull focus
  /// into its submenu.
  List<Widget> get _menuChildrenWithFocus {
    if (!isTV()) {
      return menuChildren;
    }
    var index = menuChildren.indexWhere(
        (c) => c is KazumiMenuItem && c.selected == true && c.onPressed != null);
    if (index < 0) {
      index = menuChildren
          .indexWhere((c) => c is KazumiMenuItem && c.onPressed != null);
    }
    if (index < 0) {
      return menuChildren;
    }
    return [...menuChildren]
      ..[index] = (menuChildren[index] as KazumiMenuItem).withAutofocus();
  }

  @override
  Widget build(BuildContext context) {
    return MenuButtonTheme(
      data: MenuButtonThemeData(
        // Submenu entries must use the same inset as ordinary menu items.
        style: _menuItemStyle.merge(MenuButtonTheme.of(context).style),
      ),
      child: MenuAnchor(
        controller: controller,
        consumeOutsideTap: true,
        crossAxisUnconstrained: crossAxisUnconstrained,
        animated: animated && !MediaQuery.disableAnimationsOf(context),
        onOpen: onOpen,
        onClose: onClose,
        style: style,
        menuChildren: _menuChildrenWithFocus,
        builder: (context, controller, _) => builder(
          context,
          enabled && menuChildren.isNotEmpty
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
        ),
      ),
    );
  }
}

class KazumiMenuItem extends StatelessWidget {
  const KazumiMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.selected,
    this.destructive = false,
    this.requestFocusOnHover = true,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;

  /// Null for actions; a bool exposes single-choice selection semantics.
  final bool? selected;
  final bool destructive;
  final bool requestFocusOnHover;
  final bool autofocus;

  KazumiMenuItem withAutofocus() => KazumiMenuItem(
        key: key,
        label: label,
        onPressed: onPressed,
        leadingIcon: leadingIcon,
        selected: selected,
        destructive: destructive,
        requestFocusOnHover: requestFocusOnHover,
        autofocus: true,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive
        ? colors.error
        : selected == true
        ? colors.primary
        : null;
    final foregroundColor = color == null
        ? null
        : WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled) ? null : color,
          );
    return MenuItemButton(
      onPressed: onPressed,
      requestFocusOnHover: requestFocusOnHover,
      autofocus: autofocus,
      style: ButtonStyle(
        foregroundColor: foregroundColor,
        iconColor: foregroundColor,
      ),
      leadingIcon: leadingIcon,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: selected == null ? null : true,
        child: Text(label, textAlign: TextAlign.start),
      ),
    );
  }
}
