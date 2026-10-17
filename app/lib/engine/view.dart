/// What one seat can see, plus its legal moves. Same JSON as the backend's PlayerView record.
library;

enum Phase {
  bidding('BIDDING'),
  chooseTrump('CHOOSE_TRUMP'),
  playing('PLAYING'),
  roundOver('ROUND_OVER'),
  matchOver('MATCH_OVER');

  const Phase(this.wire);

  final String wire;

  static Phase fromWire(String w) => values.firstWhere((p) => p.wire == w);
}

class BidEntry {
  const BidEntry(this.seat, this.value);

  final int seat;

  /// null means pass.
  final int? value;

  factory BidEntry.fromJson(Map<String, dynamic> j) => BidEntry(j['seat'] as int, j['value'] as int?);

  Map<String, dynamic> toJson() => {'seat': seat, 'value': value};
}

class PlayedCard {
  const PlayedCard(this.seat, this.card);

  final int seat;
  final String card;

  factory PlayedCard.fromJson(Map<String, dynamic> j) => PlayedCard(j['seat'] as int, j['card'] as String);

  Map<String, dynamic> toJson() => {'seat': seat, 'card': card};
}

class RoundResult {
  const RoundResult(this.bidder, this.bid, this.target, this.bidderTeamPoints, this.success, this.delta);

  final int bidder;
  final int bid;
  final int target;
  final int bidderTeamPoints;
  final bool success;
  final int delta;

  factory RoundResult.fromJson(Map<String, dynamic> j) => RoundResult(
    j['bidder'] as int,
    j['bid'] as int,
    j['target'] as int,
    j['bidderTeamPoints'] as int,
    j['success'] as bool,
    j['delta'] as int,
  );

  Map<String, dynamic> toJson() => {
    'bidder': bidder,
    'bid': bid,
    'target': target,
    'bidderTeamPoints': bidderTeamPoints,
    'success': success,
    'delta': delta,
  };
}

class Legal {
  const Legal({
    this.bids = const [],
    this.canPass = false,
    this.trumpCards = const [],
    this.cards = const [],
    this.canRevealTrump = false,
    this.canShowPair = false,
  });

  static const none = Legal();

  final List<int> bids;
  final bool canPass;
  final List<String> trumpCards;
  final List<String> cards;
  final bool canRevealTrump;
  final bool canShowPair;

  bool get isEmpty =>
      bids.isEmpty && !canPass && trumpCards.isEmpty && cards.isEmpty && !canRevealTrump && !canShowPair;

  factory Legal.fromJson(Map<String, dynamic> j) => Legal(
    bids: (j['bids'] as List).cast<int>(),
    canPass: j['canPass'] as bool,
    trumpCards: (j['trumpCards'] as List).cast<String>(),
    cards: (j['cards'] as List).cast<String>(),
    canRevealTrump: j['canRevealTrump'] as bool,
    canShowPair: j['canShowPair'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'bids': bids,
    'canPass': canPass,
    'trumpCards': trumpCards,
    'cards': cards,
    'canRevealTrump': canRevealTrump,
    'canShowPair': canShowPair,
  };
}

class PlayerView {
  const PlayerView({
    required this.seat,
    required this.phase,
    required this.round,
    required this.dealer,
    required this.turn,
    required this.hand,
    required this.hiddenTrump,
    required this.trump,
    required this.trumpRevealed,
    required this.bids,
    required this.highestBid,
    required this.bidder,
    required this.target,
    required this.trick,
    required this.lastTrick,
    required this.lastTrickWinner,
    required this.played,
    required this.teamPoints,
    required this.matchScore,
    required this.handCounts,
    required this.pairShownBy,
    required this.tricksPlayed,
    required this.lastRound,
    required this.matchWinner,
    required this.legal,
  });

  final int seat;
  final Phase phase;
  final int round;
  final int dealer;
  final int turn;
  final List<String> hand;
  final String? hiddenTrump;

  /// Trump suit code, only when this seat may know it (bidder, or after reveal).
  final String? trump;
  final bool trumpRevealed;
  final List<BidEntry> bids;
  final int highestBid;
  final int bidder;
  final int target;
  final List<PlayedCard> trick;
  final List<PlayedCard> lastTrick;
  final int lastTrickWinner;
  final List<String> played;
  final List<int> teamPoints;
  final List<int> matchScore;
  final List<int> handCounts;
  final int pairShownBy;
  final int tricksPlayed;
  final RoundResult? lastRound;
  final int matchWinner;
  final Legal legal;

  bool get myTurn => turn == seat && !legal.isEmpty;

  int get myTeam => seat % 2;

  factory PlayerView.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List).map((e) => f(e as Map<String, dynamic>)).toList();
    return PlayerView(
      seat: j['seat'] as int,
      phase: Phase.fromWire(j['phase'] as String),
      round: j['round'] as int,
      dealer: j['dealer'] as int,
      turn: j['turn'] as int,
      hand: (j['hand'] as List).cast<String>(),
      hiddenTrump: j['hiddenTrump'] as String?,
      trump: j['trump'] as String?,
      trumpRevealed: j['trumpRevealed'] as bool,
      bids: list('bids', BidEntry.fromJson),
      highestBid: j['highestBid'] as int,
      bidder: j['bidder'] as int,
      target: j['target'] as int,
      trick: list('trick', PlayedCard.fromJson),
      lastTrick: list('lastTrick', PlayedCard.fromJson),
      lastTrickWinner: j['lastTrickWinner'] as int,
      played: (j['played'] as List).cast<String>(),
      teamPoints: (j['teamPoints'] as List).cast<int>(),
      matchScore: (j['matchScore'] as List).cast<int>(),
      handCounts: (j['handCounts'] as List).cast<int>(),
      pairShownBy: j['pairShownBy'] as int,
      tricksPlayed: j['tricksPlayed'] as int,
      lastRound: j['lastRound'] == null ? null : RoundResult.fromJson(j['lastRound'] as Map<String, dynamic>),
      matchWinner: j['matchWinner'] as int,
      legal: Legal.fromJson(j['legal'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'seat': seat,
    'phase': phase.wire,
    'round': round,
    'dealer': dealer,
    'turn': turn,
    'hand': hand,
    'hiddenTrump': hiddenTrump,
    'trump': trump,
    'trumpRevealed': trumpRevealed,
    'bids': bids.map((b) => b.toJson()).toList(),
    'highestBid': highestBid,
    'bidder': bidder,
    'target': target,
    'trick': trick.map((p) => p.toJson()).toList(),
    'lastTrick': lastTrick.map((p) => p.toJson()).toList(),
    'lastTrickWinner': lastTrickWinner,
    'played': played,
    'teamPoints': teamPoints,
    'matchScore': matchScore,
    'handCounts': handCounts,
    'pairShownBy': pairShownBy,
    'tricksPlayed': tricksPlayed,
    'lastRound': lastRound?.toJson(),
    'matchWinner': matchWinner,
    'legal': legal.toJson(),
  };
}
