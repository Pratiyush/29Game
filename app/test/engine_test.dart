import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game29/engine/bot.dart';
import 'package:game29/engine/cards.dart';
import 'package:game29/engine/game.dart';
import 'package:game29/engine/view.dart';

void main() {
  test('deck has 32 cards worth 28 points', () {
    expect(Card.deck.length, 32);
    expect(Card.deck.fold<int>(0, (s, c) => s + c.points), 28);
  });

  test('first bidder is left of dealer and the last player is forced to bid', () {
    final g = Game(Random(1), firstDealer: 0);
    expect(g.turn, 1);
    g.pass(1);
    g.pass(2);
    g.pass(3);
    expect(g.view(0).legal.canPass, isFalse);
    expect(() => g.pass(0), throwsA(isA<IllegalMoveException>()));
    g.bid(0, 16);
    expect(g.phase, Phase.chooseTrump);
  });

  test('trump stays hidden from other seats until revealed', () {
    final g = Game(Random(3), firstDealer: 0);
    g.bid(1, 16);
    g.pass(2);
    g.pass(3);
    g.pass(0);
    final hide = g.hand(1).first;
    g.chooseTrump(1, hide);
    expect(g.view(1).hiddenTrump, hide.code);
    expect(g.view(1).handCounts[1], 8);
    expect(g.view(0).trump, isNull);
    expect(g.view(0).hiddenTrump, isNull);
  });

  test('trick winner honours trump only once revealed', () {
    const trick = [PlayedCard(0, '7H'), PlayedCard(1, 'JH'), PlayedCard(2, '7S'), PlayedCard(3, '9H')];
    expect(Game.winnerOf(trick, null), 1);
    expect(Game.winnerOf(trick, Suit.spades), 2);
  });

  test('view JSON round-trips', () {
    final g = Game(Random(5));
    final v = g.view(g.turn);
    expect(PlayerView.fromJson(v.toJson()).toJson(), v.toJson());
  });

  test('bots finish many matches with only legal moves', () {
    final rnd = Random(42);
    for (var match = 0; match < 100; match++) {
      final bot = Bot(match % 3 == 0 ? BotLevel.easy : BotLevel.normal, rnd);
      final g = Game(rnd);
      var rounds = 0;
      while (g.phase != Phase.matchOver && rounds < 500) {
        if (g.phase == Phase.roundOver) {
          g.nextRound();
          rounds++;
          continue;
        }
        final v = g.view(g.turn);
        expect(v.legal.isEmpty, isFalse);
        g.apply(g.turn, bot.decide(v));
        if (g.phase == Phase.roundOver || g.phase == Phase.matchOver) {
          expect(g.teamPoints[0] + g.teamPoints[1], 28);
        }
      }
      expect(g.phase, Phase.matchOver);
    }
  });

  test('normal bots out-score random bots', () {
    final rnd = Random(7);
    final smart = Bot(BotLevel.normal, rnd);
    final dumb = Bot(BotLevel.easy, rnd);
    var smartPts = 0, dumbPts = 0;
    for (var i = 0; i < 300; i++) {
      final g = Game(rnd);
      while (g.phase != Phase.roundOver && g.phase != Phase.matchOver) {
        final seat = g.turn;
        g.apply(seat, (Game.teamOf(seat) == 0 ? smart : dumb).decide(g.view(seat)));
      }
      smartPts += g.teamPoints[0];
      dumbPts += g.teamPoints[1];
    }
    expect(smartPts, greaterThan(dumbPts * 1.2));
  });
}
