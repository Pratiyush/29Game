package com.game29.room;

/** Delivers a server message to a connected player. Implemented by the WebSocket layer. */
public interface Outbox {
    void send(String playerId, Object message);
}
