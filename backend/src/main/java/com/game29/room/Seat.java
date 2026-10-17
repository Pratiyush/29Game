package com.game29.room;

/** Who sits in a seat. A human who disconnects keeps the seat; a bot plays for them until they return. */
public final class Seat {
    final String playerId;
    final String name;
    final boolean bot;
    boolean connected;

    Seat(String playerId, String name, boolean bot) {
        this.playerId = playerId;
        this.name = name;
        this.bot = bot;
        this.connected = !bot;
    }

    /** True when the server must move for this seat. */
    boolean autoPlay() {
        return bot || !connected;
    }
}
