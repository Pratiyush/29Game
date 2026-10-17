/// 29 rules for one match. Dart port of backend/.../engine/Game.java — keep the two in sync.
/// Used by the phone when it is the host: offline vs bots, Bluetooth host, and the mock backend.
library;

import 'dart:math';

import 'action.dart';
import 'cards.dart';
import 'view.dart';

class IllegalMoveException implements Exception {
  IllegalMoveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Game {
  Game(this._random, {int? firstDealer}) {
    _dealer = ((firstDealer ?? _random.nextInt(seats)) + seats - 1) % seats; // startRound advances it
    _startRound();
  }

  static const seats = 4;
  static const minBid = 16;
  static const maxBid = 28;
  static const pairBonus = 4;
  static const matchPointsToWin = 6;
  static const tricksPerRound = 8;

  static int teamOf(int seat) => seat % 2;

  static int next(int seat) => (seat + 1) % seats;

  final Random _random;

  Phase _phase = Phase.bidding;
  int _round = 0;
  late int _dealer;
  int _turn = -1;

  final List<List<Card>> _hands = List.generate(seats, (_) => <Card>[]);
  final List<Card> _stock = [];

  final List<BidEntry> _bids = [];
  final List<bool> _passed = List.filled(seats, false);
  int _highestBid = 0;
  int _bidder = -1;

  Suit? _trump;
  Card? _hiddenTrump;
  bool _trumpRevealed = false;
  int _revealedThisTrickBy = -1;

  final List<PlayedCard> _trick = [];
  List<PlayedCard> _lastTrick = const [];
  int _lastTrickWinner = -1;
  final List<Card> _played = [];
  final List<int> _teamPoints = [0, 0];
  final List<bool> _wonTrickAfterReveal = [false, false];
  int _tricksPlayed = 0;
  int _target = 0;
  int _pairShownBy = -1;

  final List<int> _matchScore = [0, 0];
  RoundResult? _lastRound;
  int _matchWinner = -1;

  Phase get phase => _phase;
  int get turn => _turn;
  int get bidder => _bidder;
  int get round => _round;
  int get tricksPlayed => _tricksPlayed;
  bool get trickEmpty => _trick.isEmpty;
  List<int> get teamPoints => List.of(_teamPoints);
  List<int> get matchScore => List.of(_matchScore);
  List<Card> hand(int seat) => List.of(_hands[seat]);

  // ---------------------------------------------------------------- round lifecycle

  void _startRound() {
    _round++;
    _dealer = next(_dealer);
    _phase = Phase.bidding;
    for (final h in _hands) {
      h.clear();
    }
    _stock.clear();
    _bids.clear();
    _passed.fillRange(0, seats, false);
    _highestBid = 0;
    _bidder = -1;
    _trump = null;
    _hiddenTrump = null;
    _trumpRevealed = false;
    _revealedThisTrickBy = -1;
    _trick.clear();
    _lastTrick = const [];
    _lastTrickWinner = -1;
    _played.clear();
    _teamPoints.fillRange(0, 2, 0);
    _wonTrickAfterReveal.fillRange(0, 2, false);
    _tricksPlayed = 0;
    _target = 0;
    _pairShownBy = -1;

    _stock.addAll(List.of(Card.deck)..shuffle(_random));
    _deal(4);
    _turn = next(_dealer);
  }

  void _deal(int perSeat) {
    for (var i = 0; i < perSeat; i++) {
      for (var s = 1; s <= seats; s++) {
        _hands[(_dealer + s) % seats].add(_stock.removeLast());
      }
    }
  }

  void nextRound() {
    if (_phase != Phase.roundOver) throw IllegalMoveException('Round is not over');
    _startRound();
  }

  // ---------------------------------------------------------------- actions

  void apply(int seat, GameAction action) {
    switch (action) {
      case BidAction(:final value):
        bid(seat, value);
      case PassAction():
        pass(seat);
      case ChooseTrumpAction(:final card):
        chooseTrump(seat, card);
      case PlayAction(:final card):
        play(seat, card);
      case RevealTrumpAction():
        revealTrump(seat);
      case ShowPairAction():
        showPair(seat);
    }
  }

  void bid(int seat, int value) {
    _requireTurn(seat, Phase.bidding);
    final min = max(minBid, _highestBid + 1);
    if (value < min || value > maxBid) throw IllegalMoveException('Bid must be between $min and $maxBid');
    _bids.add(BidEntry(seat, value));
    _highestBid = value;
    _bidder = seat;
    _advanceBidding();
  }

  void pass(int seat) {
    _requireTurn(seat, Phase.bidding);
    if (!_canPass()) throw IllegalMoveException('Everyone else passed: you must bid');
    _bids.add(BidEntry(seat, null));
    _passed[seat] = true;
    _advanceBidding();
  }

  bool _canPass() => !(_bidder == -1 && _passedCount == seats - 1);

  int get _passedCount => _passed.where((p) => p).length;

  void _advanceBidding() {
    if (_bidder != -1 && (_passedCount == seats - 1 || _highestBid == maxBid)) {
      _phase = Phase.chooseTrump;
      _turn = _bidder;
      return;
    }
    var s = next(_turn);
    while (_passed[s]) {
      s = next(s);
    }
    _turn = s;
  }

  void chooseTrump(int seat, Card card) {
    _requireTurn(seat, Phase.chooseTrump);
    if (!_hands[seat].remove(card)) throw IllegalMoveException('You do not hold $card');
    _hiddenTrump = card;
    _trump = card.suit;
    _target = _highestBid;
    _deal(4);
    _phase = Phase.playing;
    _turn = next(_dealer);
    _autoRevealIfNeeded();
  }

  void revealTrump(int seat) {
    _requireTurn(seat, Phase.playing);
    if (!canRevealTrump(seat)) throw IllegalMoveException('You cannot ask for trump now');
    _doReveal(seat);
  }

  void _doReveal(int seat) {
    _trumpRevealed = true;
    _revealedThisTrickBy = seat;
    _hands[_bidder].add(_hiddenTrump!);
    _hiddenTrump = null;
  }

  void showPair(int seat) {
    _requireTurn(seat, Phase.playing);
    if (!canShowPair(seat)) throw IllegalMoveException('You cannot show a pair now');
    _pairShownBy = seat;
    if (teamOf(seat) == teamOf(_bidder)) {
      _target = max(minBid, _target - pairBonus);
    } else {
      _target = min(maxBid, _target + pairBonus);
    }
  }

  void play(int seat, Card card) {
    _requireTurn(seat, Phase.playing);
    if (!legalCards(seat).contains(card)) throw IllegalMoveException('You cannot play $card now');
    _hands[seat].remove(card);
    _trick.add(PlayedCard(seat, card.code));
    if (_trick.length < seats) {
      _turn = next(seat);
      _autoRevealIfNeeded();
      return;
    }
    final winner = currentWinner();
    final team = teamOf(winner);
    for (final p in _trick) {
      final c = Card.parse(p.card);
      _teamPoints[team] += c.points;
      _played.add(c);
    }
    if (_trumpRevealed) _wonTrickAfterReveal[team] = true;
    _lastTrick = List.unmodifiable(_trick);
    _lastTrickWinner = winner;
    _trick.clear();
    _revealedThisTrickBy = -1;
    _tricksPlayed++;
    if (_tricksPlayed == tricksPerRound) {
      _endRound();
    } else {
      _turn = winner;
      _autoRevealIfNeeded();
    }
  }

  void _autoRevealIfNeeded() {
    if (_phase == Phase.playing && !_trumpRevealed && _turn == _bidder && _hands[_bidder].isEmpty) {
      _doReveal(_bidder);
    }
  }

  void _endRound() {
    final bidderTeam = teamOf(_bidder);
    final success = _teamPoints[bidderTeam] >= _target;
    final delta = success ? 1 : -1;
    _matchScore[bidderTeam] += delta;
    _lastRound = RoundResult(_bidder, _highestBid, _target, _teamPoints[bidderTeam], success, delta);
    _turn = -1;
    _phase = Phase.roundOver;
    for (var t = 0; t < 2; t++) {
      if (_matchScore[t] >= matchPointsToWin) {
        _matchWinner = t;
      } else if (_matchScore[t] <= -matchPointsToWin) {
        _matchWinner = 1 - t;
      }
    }
    if (_matchWinner != -1) _phase = Phase.matchOver;
  }

  void _requireTurn(int seat, Phase expected) {
    if (_phase != expected) throw IllegalMoveException('Not allowed during ${_phase.wire}');
    if (seat != _turn) throw IllegalMoveException('Not your turn');
  }

  // ---------------------------------------------------------------- rules queries

  List<Card> legalCards(int seat) {
    if (_phase != Phase.playing || seat != _turn) return const [];
    final hand = _hands[seat];
    if (_trick.isEmpty) return List.of(hand);
    final led = Card.parse(_trick.first.card).suit;
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) return follow;
    if (_trumpRevealed && _revealedThisTrickBy == seat) {
      final trumps = hand.where((c) => c.suit == _trump).toList();
      if (trumps.isNotEmpty) return trumps;
    }
    return List.of(hand);
  }

  bool canRevealTrump(int seat) {
    if (_phase != Phase.playing || seat != _turn || _trumpRevealed || _trick.isEmpty) return false;
    final led = Card.parse(_trick.first.card).suit;
    return !_hands[seat].any((c) => c.suit == led);
  }

  bool canShowPair(int seat) {
    if (_phase != Phase.playing || seat != _turn || !_trumpRevealed || _pairShownBy != -1) return false;
    if (!_wonTrickAfterReveal[teamOf(seat)]) return false;
    final hand = _hands[seat];
    return hand.contains(Card(Rank.king, _trump!)) && hand.contains(Card(Rank.queen, _trump!));
  }

  int currentWinner() => winnerOf(_trick, _trumpRevealed ? _trump : null);

  static int winnerOf(List<PlayedCard> trick, Suit? effectiveTrump) {
    if (trick.isEmpty) return -1;
    var best = trick.first;
    for (final p in trick.skip(1)) {
      if (beats(Card.parse(p.card), Card.parse(best.card), effectiveTrump)) best = p;
    }
    return best.seat;
  }

  static bool beats(Card challenger, Card best, Suit? trump) {
    if (trump != null) {
      if (challenger.suit == trump && best.suit != trump) return true;
      if (best.suit == trump && challenger.suit != trump) return false;
    }
    return challenger.suit == best.suit && challenger.rank.power > best.rank.power;
  }

  // ---------------------------------------------------------------- views

  PlayerView view(int seat) {
    final seesTrump = _trump != null && (_trumpRevealed || seat == _bidder);
    return PlayerView(
      seat: seat,
      phase: _phase,
      round: _round,
      dealer: _dealer,
      turn: _turn,
      hand: _sortedHand(seat).map((c) => c.code).toList(),
      hiddenTrump: seat == _bidder ? _hiddenTrump?.code : null,
      trump: seesTrump ? _trump!.code : null,
      trumpRevealed: _trumpRevealed,
      bids: List.of(_bids),
      highestBid: _highestBid,
      bidder: _bidder,
      target: _target,
      trick: List.of(_trick),
      lastTrick: _lastTrick,
      lastTrickWinner: _lastTrickWinner,
      played: _played.map((c) => c.code).toList(),
      teamPoints: List.of(_teamPoints),
      matchScore: List.of(_matchScore),
      handCounts: [for (var s = 0; s < seats; s++) _hands[s].length + (s == _bidder && _hiddenTrump != null ? 1 : 0)],
      pairShownBy: _pairShownBy,
      tricksPlayed: _tricksPlayed,
      lastRound: _lastRound,
      matchWinner: _matchWinner,
      legal: _legal(seat),
    );
  }

  Legal _legal(int seat) {
    if (seat != _turn) return Legal.none;
    return switch (_phase) {
      Phase.bidding => Legal(
        bids: [for (var v = max(minBid, _highestBid + 1); v <= maxBid; v++) v],
        canPass: _canPass(),
      ),
      Phase.chooseTrump => Legal(trumpCards: _hands[seat].map((c) => c.code).toList()),
      Phase.playing => Legal(
        cards: legalCards(seat).map((c) => c.code).toList(),
        canRevealTrump: canRevealTrump(seat),
        canShowPair: canShowPair(seat),
      ),
      _ => Legal.none,
    };
  }

  List<Card> _sortedHand(int seat) =>
      List.of(_hands[seat])
        ..sort((a, b) => a.suit != b.suit ? a.suit.index - b.suit.index : b.rank.power - a.rank.power);
}
