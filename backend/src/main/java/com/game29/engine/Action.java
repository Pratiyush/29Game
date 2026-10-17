package com.game29.engine;

/** A move a seat can make. Mirrors the client->host messages in docs/PROTOCOL.md. */
public sealed interface Action {

    record Bid(int value) implements Action {}

    record Pass() implements Action {}

    record ChooseTrump(Card card) implements Action {}

    record Play(Card card) implements Action {}

    record RevealTrump() implements Action {}

    record ShowPair() implements Action {}

    static void apply(Game game, int seat, Action action) {
        switch (action) {
            case Bid b -> game.bid(seat, b.value());
            case Pass p -> game.pass(seat);
            case ChooseTrump c -> game.chooseTrump(seat, c.card());
            case Play p -> game.play(seat, p.card());
            case RevealTrump r -> game.revealTrump(seat);
            case ShowPair s -> game.showPair(seat);
        }
    }
}
