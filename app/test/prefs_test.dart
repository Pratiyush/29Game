import 'package:flutter_test/flutter_test.dart';
import 'package:game29/engine/view.dart';
import 'package:game29/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlayerView _ended({required int seat, required int bidder, required bool success, Phase phase = Phase.roundOver}) {
  return PlayerView(
    seat: seat,
    phase: phase,
    round: 1,
    dealer: 0,
    turn: -1,
    hand: const [],
    hiddenTrump: null,
    trump: 'S',
    trumpRevealed: true,
    bids: const [],
    highestBid: 18,
    bidder: bidder,
    target: 18,
    trick: const [],
    lastTrick: const [],
    lastTrickWinner: 0,
    played: const [],
    teamPoints: const [20, 8],
    matchScore: const [6, 0],
    handCounts: const [0, 0, 0, 0],
    pairShownBy: -1,
    tricksPlayed: 8,
    lastRound: RoundResult(bidder, 18, 18, 20, success, success ? 1 : -1),
    matchWinner: phase == Phase.matchOver ? 0 : -1,
    legal: Legal.none,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.load();
  });

  test('a made contract counts once, even if the same state arrives twice', () {
    final p = Prefs.instance;
    final v = _ended(seat: 0, bidder: 0, success: true);
    p.recordDeal('T1', v);
    p.recordDeal('T1', v);
    expect(p.dealsPlayed, 1);
    expect(p.dealsWon, 1);
    expect(p.bidsWon, 1);
    expect(p.contractsMade, 1);
    expect(p.highestBid, 18);
    expect(p.streak, 1);
    expect(p.xp, 45);
  });

  test('defending successfully is a won deal; a match win adds to matches', () {
    final p = Prefs.instance;
    p.recordDeal('T1', _ended(seat: 0, bidder: 1, success: false, phase: Phase.matchOver));
    expect(p.dealsWon, 1);
    expect(p.bidsWon, 0);
    expect(p.matchesPlayed, 1);
    expect(p.matchesWon, 1);
  });

  test('a lost deal resets the streak but keeps the best', () {
    final p = Prefs.instance;
    p.recordDeal('A', _ended(seat: 0, bidder: 0, success: true));
    p.recordDeal('B', _ended(seat: 0, bidder: 0, success: false));
    expect(p.streak, 0);
    expect(p.bestStreak, 1);
  });

  test('a new player gets a valid random avatar that sticks', () {
    final a = Prefs.instance.avatar;
    expect(a, inInclusiveRange(0, 15));
    expect(Prefs.instance.avatar, a);
  });
}
