package com.game29.engine;

import java.util.ArrayList;
import java.util.List;

/** A card, serialised as rank+suit, e.g. "JS" (jack of spades) or "TH" (ten of hearts). */
public record Card(Rank rank, Suit suit) {

    private static final List<Card> DECK;

    static {
        List<Card> deck = new ArrayList<>(32);
        for (Suit s : Suit.values()) {
            for (Rank r : Rank.values()) {
                deck.add(new Card(r, s));
            }
        }
        DECK = List.copyOf(deck);
    }

    public static List<Card> deck() {
        return DECK;
    }

    public static Card parse(String code) {
        if (code == null || code.length() != 2) {
            throw new IllegalArgumentException("Bad card: " + code);
        }
        return new Card(Rank.fromCode(code.charAt(0)), Suit.fromCode(code.charAt(1)));
    }

    public int points() {
        return rank.points;
    }

    public String code() {
        return "" + rank.code + suit.code;
    }

    @Override
    public String toString() {
        return code();
    }
}
