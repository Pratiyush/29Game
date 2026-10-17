import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prefs.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await Prefs.load();
  runApp(Game29App(prefs: prefs));
}

class Game29App extends StatelessWidget {
  const Game29App({super.key, required this.prefs});

  final Prefs prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '29',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(prefs: prefs),
    );
  }
}
