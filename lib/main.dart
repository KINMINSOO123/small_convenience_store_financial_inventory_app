import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmallConvenienceStore());
}

class SmallConvenienceStore extends StatelessWidget {
  const SmallConvenienceStore({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convenience Store Inventory & Financial App',
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}
