/// Cards for 29. Wire format is rank+suit, e.g. "JS" or "TH" (shared with the backend).
library;

enum Suit {
  clubs('C', '♣'),
  diamonds('D', '♦'),
  hearts('H', '♥'),
  spades('S', '♠');

  const Suit(this.code, this.symbol);

  final String code;
  final String symbol;

  bool get isRed => this == diamonds || this == hearts;

  static Suit fromCode(String c) =>
      values.firstWhere((s) => s.code == c, orElse: () => throw ArgumentError('Unknown suit: $c'));
}

/// Ranks from highest to lowest trick-taking power.
enum Rank {
  jack('J', 3, 8),
  nine('9', 2, 7),
  ace('A', 1, 6),
  ten('T', 1, 5),
  king('K', 0, 4),
  queen('Q', 0, 3),
  eight('8', 0, 2),
  seven('7', 0, 1);

  const Rank(this.code, this.points, this.power);

  final String code;
  final int points;
  final int power;

  String get label => this == ten ? '10' : code;

  static Rank fromCode(String c) =>
      values.firstWhere((r) => r.code == c, orElse: () => throw ArgumentError('Unknown rank: $c'));
}

class Card {
  const Card(this.rank, this.suit);

  final Rank rank;
  final Suit suit;

  static final List<Card> deck = List.unmodifiable([
    for (final s in Suit.values)
      for (final r in Rank.values) Card(r, s),
  ]);

  static Card parse(String code) {
    if (code.length != 2) throw ArgumentError('Bad card: $code');
    return Card(Rank.fromCode(code[0]), Suit.fromCode(code[1]));
  }

  int get points => rank.points;

  String get code => '${rank.code}${suit.code}';

  @override
  bool operator ==(Object other) => other is Card && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => rank.index * 4 + suit.index;

  @override
  String toString() => code;
}
