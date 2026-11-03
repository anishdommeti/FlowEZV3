import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final mode = themeProvider.mode;
    final icon = switch (mode) {
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };

    return IconButton(
      icon: Icon(icon),
      tooltip: 'Switch theme',
      onPressed: () async {
        final selected = await showModalBottomSheet<ThemeMode>(
          context: context,
          builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values.map((candidate) {
                return ListTile(
                  leading: Icon(
                    switch (candidate) {
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                      ThemeMode.system => Icons.brightness_auto_rounded,
                    },
                  ),
                  title: Text(candidate.name.toCapitalized()),
                  trailing: mode == candidate ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(candidate),
                );
              }).toList(),
            );
          },
        );

        if (selected != null) {
          await themeProvider.setThemeMode(selected);
        }
      },
    );
  }
}

extension on String {
  String toCapitalized() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1).toLowerCase();
  }
}
