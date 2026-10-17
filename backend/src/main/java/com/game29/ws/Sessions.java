package com.game29.ws;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.game29.room.Outbox;
import io.quarkus.logging.Log;
import io.quarkus.websockets.next.WebSocketConnection;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Maps player ids to live WebSocket connections and sends JSON without blocking. */
@ApplicationScoped
public class Sessions implements Outbox {

    @Inject
    ObjectMapper mapper;

    private final Map<String, WebSocketConnection> byPlayer = new ConcurrentHashMap<>();
    private final Map<String, String> playerByConnection = new ConcurrentHashMap<>();
    private final Map<String, String> names = new ConcurrentHashMap<>();
    private final Map<String, Integer> avatars = new ConcurrentHashMap<>();

    void bind(String playerId, String name, int avatar, WebSocketConnection connection) {
        names.put(playerId, name);
        avatars.put(playerId, avatar);
        String previousPlayer = playerByConnection.put(connection.id(), playerId);
        if (previousPlayer != null && !previousPlayer.equals(playerId)) byPlayer.remove(previousPlayer, connection);
        WebSocketConnection old = byPlayer.put(playerId, connection);
        if (old != null && old != connection) {
            // Same player opened a second connection (e.g. app resumed): the newest one wins.
            playerByConnection.remove(old.id());
            old.close().subscribe().with(x -> {}, t -> {});
        }
    }

    /** Returns the player bound to this connection, if it was still the active one. */
    String unbind(WebSocketConnection connection) {
        String playerId = playerByConnection.remove(connection.id());
        if (playerId != null && byPlayer.remove(playerId, connection)) {
            names.remove(playerId);
            avatars.remove(playerId);
            return playerId;
        }
        return null;
    }

    String nameOf(String playerId) {
        return names.getOrDefault(playerId, "");
    }

    int avatarOf(String playerId) {
        return avatars.getOrDefault(playerId, -1);
    }

    String playerOf(WebSocketConnection connection) {
        return playerByConnection.get(connection.id());
    }

    @Override
    public void send(String playerId, Object message) {
        WebSocketConnection c = byPlayer.get(playerId);
        if (c == null || !c.isOpen()) return;
        send(c, message);
    }

    void send(WebSocketConnection c, Object message) {
        try {
            c.sendText(mapper.writeValueAsString(message))
                    .subscribe().with(x -> {}, t -> Log.debugf("send failed: %s", t.getMessage()));
        } catch (JsonProcessingException e) {
            Log.error("Could not serialise message", e);
        }
    }
}
