import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vimer/src/app.dart';
import 'package:vimer/src/services/prefs.dart';
import 'package:vimer/src/state/providers.dart';

void main() {
  testWidgets('boots to an empty, ready panel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(Prefs(prefs))],
        child: const VimerApp(),
      ),
    );
    // A single frame; the panel has looping animations so don't settle.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('No timers yet'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });
}
