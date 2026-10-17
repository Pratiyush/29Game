package com.game29.engine;

/** Ranks used in 29, declared from highest to lowest trick-taking power. */
public enum Rank {
    JACK('J', 3, 8),
    NINE('9', 2, 7),
    ACE('A', 1, 6),
    TEN('T', 1, 5),
    KING('K', 0, 4),
    QUEEN('Q', 0, 3),
    EIGHT('8', 0, 2),
    SEVEN('7', 0, 1);

    public final char code;
    public final int points;
    /** Higher wins within a suit. */
    public final int power;

    Rank(char code, int points, int power) {
        this.code = code;
        this.points = points;
        this.power = power;
    }

    public static Rank fromCode(char c) {
        for (Rank r : values()) {
            if (r.code == c) return r;
        }
        throw new IllegalArgumentException("Unknown rank: " + c);
    }
}
