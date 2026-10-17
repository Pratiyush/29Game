package com.game29.engine;

public enum Suit {
    CLUBS('C'), DIAMONDS('D'), HEARTS('H'), SPADES('S');

    public final char code;

    Suit(char code) {
        this.code = code;
    }

    public static Suit fromCode(char c) {
        for (Suit s : values()) {
            if (s.code == c) return s;
        }
        throw new IllegalArgumentException("Unknown suit: " + c);
    }
}
