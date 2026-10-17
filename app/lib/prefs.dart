import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine/bot.dart';
import 'engine/view.dart';
import 'net/emotes.dart';

enum GameSpeed {
  relaxed(Duration(milliseconds: 1100)),
  normal(Duration(milliseconds: 700)),
  fast(Duration(milliseconds: 380));

  const GameSpeed(this.botDelay);

  /// How long bots think before moving (offline and when hosting nearby).
  final Duration botDelay;
}

/// Persisted profile, settings and lifetime stats. Notifies listeners so the home screen
/// header (level bar, avatar) stays current after a game.
class Prefs extends ChangeNotifier {
  Prefs._(this._p);

  final SharedPreferences _p;

  /// Loaded once in main(); widgets read settings such as sound and card back from here.
  static late Prefs instance;

  static Future<Prefs> load() async => instance = Prefs._(await SharedPreferences.getInstance());

  void _set(String key, Object v) {
    switch (v) {
      case String s:
        _p.setString(key, s);
      case int i:
        _p.setInt(key, i);
      case bool b:
        _p.setBool(key, b);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- identity

  String get name => _p.getString('name') ?? '';
  set name(String v) => _set('name', v);

  String get playerId {
    var id = _p.getString('playerId');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _p.setString('playerId', id);
    }
    return id;
  }

  /// Chosen portrait; a random one is picked the first time.
  int get avatar {
    var a = _p.getInt('avatar');
    if (a == null || a < 0 || a >= avatarCount) {
      a = Random().nextInt(avatarCount);
      _p.setInt('avatar', a);
    }
    return a;
  }

  set avatar(int v) => _set('avatar', v);

  // ---------------------------------------------------------------- settings

  BotLevel get botLevel => BotLevel.values.byName(_p.getString('botLevel') ?? BotLevel.normal.name);
  set botLevel(BotLevel v) => _set('botLevel', v.name);

  GameSpeed get speed => GameSpeed.values.byName(_p.getString('speed') ?? GameSpeed.normal.name);
  set speed(GameSpeed v) => _set('speed', v.name);

  bool get sound => _p.getBool('sound') ?? true;
  set sound(bool v) => _set('sound', v);

  bool get haptics => _p.getBool('haptics') ?? true;
  set haptics(bool v) => _set('haptics', v);

  /// Small point badges (J 3, 9 2, A 1, 10 1) on the cards in your hand.
  bool get showPoints => _p.getBool('showPoints') ?? true;
  set showPoints(bool v) => _set('showPoints', v);

  /// 'back' (emerald) or 'back_red' (maroon).
  String get cardBack => _p.getString('cardBack') ?? 'back';
  set cardBack(String v) => _set('cardBack', v);

  // ---------------------------------------------------------------- stats

  int _int(String k) => _p.getInt('stat.$k') ?? 0;
  void _inc(String k, [int by = 1]) => _p.setInt('stat.$k', _int(k) + by);

  int get matchesPlayed => _int('matches');
  int get matchesWon => _int('matchesWon');
  int get dealsPlayed => _int('deals');
  int get dealsWon => _int('dealsWon');
  int get bidsWon => _int('bidsWon');
  int get contractsMade => _int('contractsMade');
  int get highestBid => _int('highestBid');
  int get streak => _int('streak');
  int get bestStreak => _int('bestStreak');
  int get xp => _int('xp');

  static const xpPerLevel = 250;
  int get level => 1 + xp ~/ xpPerLevel;
  double get levelProgress => (xp % xpPerLevel) / xpPerLevel;

  /// Records a finished deal once (keyed by match id + round so a resent state is not counted twice).
  void recordDeal(String matchId, PlayerView v) {
    final r = v.lastRound;
    if (r == null) return;
    final key = '$matchId#${v.round}';
    if (_p.getString('stat.lastDeal') == key) return;
    _p.setString('stat.lastDeal', key);

    final weBid = r.bidder % 2 == v.myTeam;
    final weWon = r.success == weBid;
    _inc('deals');
    var gained = 10;
    if (weWon) {
      _inc('dealsWon');
      _inc('streak');
      if (streak > bestStreak) _p.setInt('stat.bestStreak', streak);
      gained += 15;
    } else {
      _p.setInt('stat.streak', 0);
    }
    if (r.bidder == v.seat) {
      _inc('bidsWon');
      if (r.bid > highestBid) _p.setInt('stat.highestBid', r.bid);
      if (r.success) {
        _inc('contractsMade');
        gained += 20;
      }
    }
    if (v.phase == Phase.matchOver) {
      _inc('matches');
      if (v.matchWinner == v.myTeam) {
        _inc('matchesWon');
        gained += 60;
      }
    }
    _inc('xp', gained);
    notifyListeners();
  }
}
