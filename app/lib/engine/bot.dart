/// Rule-based 29 bot that only sees its own [PlayerView].
/// Dart port of backend/.../bot/Bot.java — keep the two in sync. Strategy notes: docs/BOTS.md.
library;

import 'dart:math';

import 'action.dart';
import 'cards.dart';
import 'game.dart';
import 'view.dart';

enum BotLevel { easy, normal }

class Bot {
  Bot(this.level, this._random);

  final BotLevel level;
  final Random _random;

  GameAction decide(PlayerView v) {
    final legal = v.legal;
    if (legal.canShowPair) return const ShowPairAction();
    switch (v.phase) {
      case Phase.bidding:
        return level == BotLevel.easy ? _easyBid(legal) : _bid(v);
      case Phase.chooseTrump:
        return _chooseTrump(v);
      case Phase.playing:
        if (level == BotLevel.easy) {
          return PlayAction(Card.parse(legal.cards[_random.nextInt(legal.cards.length)]));
        }
        return _play(v);
      default:
        throw StateError('Bot asked to act in ${v.phase}');
    }
  }

  // ---------------------------------------------------------------- bidding

  GameAction _easyBid(Legal legal) {
    if (legal.canPass && _random.nextInt(3) > 0) return const PassAction();
    return BidAction(legal.bids.first);
  }

  GameAction _bid(PlayerView v) {
    final legal = v.legal;
    if (!legal.canPass) return BidAction(legal.bids.first);
    if (legal.bids.isEmpty) return const PassAction();
    final minBid = legal.bids.first;
    final est = estimate(_cards(v.hand));
    final partnerLeads = v.bidder != -1 && Game.teamOf(v.bidder) == Game.teamOf(v.seat);
    if (partnerLeads && est < minBid + 2) return const PassAction();
    return minBid <= est ? BidAction(minBid) : const PassAction();
  }

  /// Highest bid this four-card hand is worth.
  static int estimate(List<Card> hand) {
    var points = 0;
    var hasJack = false;
    final perSuit = List.filled(4, 0);
    for (final c in hand) {
      points += c.points;
      perSuit[c.suit.index]++;
      if (c.rank == Rank.jack) hasJack = true;
    }
    final longest = perSuit.reduce(max);
    return min(12 + points + longest - (hasJack ? 0 : 1), Game.maxBid);
  }

  GameAction _chooseTrump(PlayerView v) {
    final options = _cards(v.legal.trumpCards);
    Suit? best;
    var bestScore = -1 << 30;
    for (final s in Suit.values) {
      var score = 0;
      for (final c in options.where((c) => c.suit == s)) {
        score += 3 + c.points + (c.rank == Rank.jack ? 2 : 0);
      }
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    final hide = _minBy(options.where((c) => c.suit == best), (c) => [c.rank.power]);
    return ChooseTrumpAction(hide);
  }

  // ---------------------------------------------------------------- card play

  GameAction _play(PlayerView v) {
    final legal = v.legal;
    final options = _cards(legal.cards);
    final k = _Knowledge(v);
    if (v.trick.isEmpty) return PlayAction(_lead(v, options, k));

    final led = Card.parse(v.trick.first.card).suit;
    final effectiveTrump = v.trumpRevealed ? k.trump : null;
    final winnerSeat = Game.winnerOf(v.trick, effectiveTrump);
    final winning = Card.parse(v.trick.firstWhere((p) => p.seat == winnerSeat).card);
    final partnerWinning = Game.teamOf(winnerSeat) == Game.teamOf(v.seat);
    final last = v.trick.length == Game.seats - 1;
    final trickPoints = v.trick.fold<int>(0, (s, p) => s + Card.parse(p.card).points);
    final partnerSafe =
        partnerWinning && (last || (k.isMaster(winning) && (winning.suit == effectiveTrump || !k.trumpThreat(led))));

    final following = options.any((c) => c.suit == led);
    if (following) {
      if (partnerWinning) return PlayAction(partnerSafe ? _feed(options, k) : _lowest(options, k));
      final winners = options.where((c) => Game.beats(c, winning, effectiveTrump)).toList();
      if (winners.isEmpty) return PlayAction(_lowest(options, k));
      if (last) return PlayAction(_cheapest(winners));
      final masters = winners.where(k.isMaster).toList();
      if (masters.isNotEmpty && !k.trumpThreat(led)) return PlayAction(_cheapest(masters));
      return PlayAction(_lowest(options, k));
    }

    // Void in the led suit.
    if (partnerSafe) return PlayAction(_feed(options, k));
    if (legal.canRevealTrump && !partnerWinning && (trickPoints >= 1 || !last)) {
      final bidderWithoutTrumps = v.seat == v.bidder && k.trumpsHeld == 0;
      if (!bidderWithoutTrumps || trickPoints >= 2) return const RevealTrumpAction();
    }
    if (v.trumpRevealed && !partnerWinning) {
      final trumpWinners = options.where((c) => c.suit == k.trump && Game.beats(c, winning, k.trump)).toList();
      if (trumpWinners.isNotEmpty) {
        if (last || trickPoints == 0) return PlayAction(_cheapest(trumpWinners));
        final masters = trumpWinners.where(k.isMaster).toList();
        return PlayAction(_cheapest(masters.isEmpty ? trumpWinners : masters));
      }
    }
    return PlayAction(_lowest(options, k));
  }

  Card _lead(PlayerView v, List<Card> options, _Knowledge k) {
    final ourContract = v.bidder != -1 && Game.teamOf(v.bidder) == Game.teamOf(v.seat);
    if (v.trumpRevealed && ourContract && k.unseen(k.trump) > 0) {
      final masterTrumps = options.where((c) => c.suit == k.trump && k.isMaster(c)).toList();
      if (masterTrumps.isNotEmpty) return masterTrumps.first;
    }
    var plain = options.where((c) => c.suit != k.trump).toList();
    if (plain.isEmpty) plain = options;
    final cashable = plain.where((c) => k.isMaster(c) && c.points > 0).toList();
    if (cashable.isNotEmpty) return _minBy(cashable, (c) => [-c.points]);
    return _minBy(plain, (c) => [_exposedPoints(c.suit, options, k), c.points, c.rank.power]);
  }

  static int _exposedPoints(Suit s, List<Card> hand, _Knowledge k) =>
      hand.where((c) => c.suit == s && !k.isMaster(c)).fold(0, (n, c) => n + c.points);

  static Card _feed(List<Card> options, _Knowledge k) {
    final candidates = options.where((c) => c.suit != k.trump && !k.isMaster(c) && c.points > 0).toList();
    if (candidates.isEmpty) return _lowest(options, k);
    return _minBy(candidates, (c) => [-c.points, c.rank.power]);
  }

  static Card _lowest(List<Card> options, _Knowledge k) =>
      _minBy(options, (c) => [c.suit == k.trump ? 1 : 0, c.points, c.rank.power]);

  static Card _cheapest(List<Card> winners) => _minBy(winners, (c) => [c.rank.power]);

  /// First card with the lexicographically smallest key (stable, like Java's Stream.min).
  static Card _minBy(Iterable<Card> cards, List<int> Function(Card) key) {
    Card? best;
    List<int>? bestKey;
    for (final c in cards) {
      final k = key(c);
      if (bestKey == null || _compare(k, bestKey) < 0) {
        best = c;
        bestKey = k;
      }
    }
    return best!;
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return 0;
  }

  static List<Card> _cards(List<String> codes) => codes.map(Card.parse).toList();
}

/// What this seat can deduce: cards it has seen and the trump suit if known.
class _Knowledge {
  _Knowledge(PlayerView v)
    : trump = v.trump == null ? null : Suit.fromCode(v.trump!),
      hand = v.hand.map(Card.parse).toList() {
    seen
      ..addAll(hand)
      ..addAll(v.played.map(Card.parse))
      ..addAll(v.trick.map((p) => Card.parse(p.card)));
    if (v.hiddenTrump != null) seen.add(Card.parse(v.hiddenTrump!));
  }

  final Suit? trump;
  final List<Card> hand;
  final Set<Card> seen = {};

  bool isMaster(Card c) => !Card.deck.any((o) => o.suit == c.suit && o.rank.power > c.rank.power && !seen.contains(o));

  int unseen(Suit? s) => s == null ? 0 : Card.deck.where((c) => c.suit == s && !seen.contains(c)).length;

  int get trumpsHeld => trump == null ? 0 : hand.where((c) => c.suit == trump).length;

  bool trumpThreat(Suit led) => trump != null && led != trump && unseen(trump) > 0 && unseen(led) <= 2;
}
