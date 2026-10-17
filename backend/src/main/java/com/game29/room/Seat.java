package com.game29.room;

/** Who sits in a seat. A human who disconnects keeps the seat; a bot plays for them until they return. */
public final class Seat {
    final String playerId;
    final String name;
    final boolean bot;
    /** Index into the client's bundled avatar set (assets/avatars/aNN.png). */
    final int avatar;
    boolean connected;
    /** When this player last sent an emote, for rate limiting. */
    long lastEmoteAt;

    Seat(String playerId, String name, boolean bot, int avatar) {
        this.playerId = playerId;
        this.name = name;
        this.bot = bot;
        this.avatar = avatar;
        this.connected = !bot;
    }

    /** True when the server must move for this seat. */
    boolean autoPlay() {
        return bot || !connected;
    }
}
