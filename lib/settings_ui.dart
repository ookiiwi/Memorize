import 'package:flutter/material.dart';

class SettingsList extends StatelessWidget {
  const SettingsList({super.key, this.sections = const []});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: sections,
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, this.tiles = const []});

  final Widget? title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8.0), child: title),
      Column(
        children: tiles,
      ),
    ]);
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile(
      {super.key,
      required this.title,
      this.value,
      this.onTap,
      this.padding = _defaultPadding,
      this.height = _defaultHeight})
      : _navigation = false,
        _toggle = false,
        onToggle = null;

  const SettingsTile.navigation(
      {super.key,
      required this.title,
      this.value,
      this.onTap,
      this.padding = _defaultPadding,
      this.height = _defaultHeight})
      : _navigation = true,
        _toggle = false,
        onToggle = null;

  const SettingsTile.toggle(
      {super.key,
      required this.title,
      this.value,
      this.onTap,
      required this.onToggle,
      this.padding = _defaultPadding,
      this.height = _defaultHeight})
      : _navigation = false,
        _toggle = true;

  static const _defaultPadding =
      EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0);
  static const _defaultHeight = 10.0;

  final Widget title;
  final Widget? value;
  final void Function(BuildContext context)? onTap;
  final void Function(bool value)? onToggle;
  final EdgeInsets padding;
  final double height;
  final bool _navigation;
  final bool _toggle;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      padding: padding,
      onPressed: () => onTap != null ? onTap!(context) : () {},
      child: SizedBox(
        height: 20,
        child: Row(
          children: [
            Padding(padding: const EdgeInsets.only(right: 8.0), child: title),
            const Spacer(),
            if (value != null) value!,
            if (_navigation)
              const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.keyboard_arrow_right_rounded)),
          ],
        ),
      ),
    );
  }
}
