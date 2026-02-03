import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loghr_mobile/logic/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDark = themeProvider.isDarkMode;

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
      ),
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onPressed: () async {
        await themeProvider.setThemeMode(
          themeProvider.themeMode == ThemeMode.light 
            ? ThemeMode.dark 
            : ThemeMode.light
        );
      },
    );
  }
}



