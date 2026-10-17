/// A move a seat can make, with the same JSON as the backend protocol (docs/PROTOCOL.md).
library;

import 'cards.dart';

sealed class GameAction {
  const GameAction();

  Map<String, dynamic> toJson();

  /// Parses a client message; returns null if it is not a game action (e.g. a lobby message).
  static GameAction? fromJson(Map<String, dynamic> j) => switch (j['type']) {
    'bid' => BidAction(j['value'] as int),
    'pass' => const PassAction(),
    'chooseTrump' => ChooseTrumpAction(Card.parse(j['card'] as String)),
    'play' => PlayAction(Card.parse(j['card'] as String)),
    'revealTrump' => const RevealTrumpAction(),
    'showPair' => const ShowPairAction(),
    _ => null,
  };
}

class BidAction extends GameAction {
  const BidAction(this.value);

  final int value;

  @override
  Map<String, dynamic> toJson() => {'type': 'bid', 'value': value};
}

class PassAction extends GameAction {
  const PassAction();

  @override
  Map<String, dynamic> toJson() => {'type': 'pass'};
}

class ChooseTrumpAction extends GameAction {
  const ChooseTrumpAction(this.card);

  final Card card;

  @override
  Map<String, dynamic> toJson() => {'type': 'chooseTrump', 'card': card.code};
}

class PlayAction extends GameAction {
  const PlayAction(this.card);

  final Card card;

  @override
  Map<String, dynamic> toJson() => {'type': 'play', 'card': card.code};
}

class RevealTrumpAction extends GameAction {
  const RevealTrumpAction();

  @override
  Map<String, dynamic> toJson() => {'type': 'revealTrump'};
}

class ShowPairAction extends GameAction {
  const ShowPairAction();

  @override
  Map<String, dynamic> toJson() => {'type': 'showPair'};
}
