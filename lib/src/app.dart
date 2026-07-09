import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui/home_shell.dart';

class VimerApp extends StatelessWidget {
  const VimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vimer',
      theme: vimerTheme(),
      home: const HomeShell(),
    );
  }
}
