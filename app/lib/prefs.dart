import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'engine/bot.dart';

/// Small persisted settings: display name, stable player id (for reconnects) and bot level.
class Prefs {
  Prefs._(this._p);

  final SharedPreferences _p;

  static Future<Prefs> load() async => Prefs._(await SharedPreferences.getInstance());

  String get name => _p.getString('name') ?? '';
  set name(String v) => _p.setString('name', v);

  String get playerId {
    var id = _p.getString('playerId');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _p.setString('playerId', id);
    }
    return id;
  }

  BotLevel get botLevel => BotLevel.values.byName(_p.getString('botLevel') ?? BotLevel.normal.name);
  set botLevel(BotLevel v) => _p.setString('botLevel', v.name);
}
