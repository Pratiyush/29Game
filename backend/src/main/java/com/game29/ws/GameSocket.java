package com.game29.ws;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.game29.engine.Action;
import com.game29.engine.Card;
import com.game29.engine.IllegalMoveException;
import com.game29.room.Messages;
import com.game29.room.RoomService;
import io.quarkus.websockets.next.OnClose;
import io.quarkus.websockets.next.OnTextMessage;
import io.quarkus.websockets.next.WebSocket;
import io.quarkus.websockets.next.WebSocketConnection;
import jakarta.inject.Inject;

import java.util.UUID;

/**
 * Single WebSocket endpoint for lobby and gameplay. Every message is JSON with a "type";
 * see docs/PROTOCOL.md. The first message must be "hello".
 */
@WebSocket(path = "/ws")
public class GameSocket {

    private static final int MAX_NAME = 16;

    @Inject
    RoomService rooms;

    @Inject
    Sessions sessions;

    @Inject
    ObjectMapper mapper;

    @OnTextMessage
    void onMessage(String text, WebSocketConnection connection) {
        try {
            JsonNode msg = mapper.readTree(text);
            String type = msg.path("type").asText();
            if ("hello".equals(type)) {
                hello(msg, connection);
                return;
            }
            String playerId = sessions.playerOf(connection);
            if (playerId == null) throw new IllegalMoveException("Say hello first");
            String name = msg.hasNonNull("name") ? msg.path("name").asText() : sessions.nameOf(playerId);
            switch (type) {
                case "quickMatch" -> rooms.quickMatch(playerId, cleanName(name));
                case "createRoom" -> rooms.createRoom(playerId, cleanName(name));
                case "joinRoom" -> rooms.joinRoom(playerId, cleanName(name), msg.path("code").asText());
                case "addBot" -> rooms.addBot(playerId);
                case "startGame" -> rooms.start(playerId);
                case "leaveRoom" -> {
                    rooms.leave(playerId);
                    sessions.send(connection, Messages.Left.INSTANCE);
                }
                case "bid" -> rooms.act(playerId, new Action.Bid(msg.path("value").asInt()));
                case "pass" -> rooms.act(playerId, new Action.Pass());
                case "chooseTrump" -> rooms.act(playerId, new Action.ChooseTrump(Card.parse(msg.path("card").asText())));
                case "play" -> rooms.act(playerId, new Action.Play(Card.parse(msg.path("card").asText())));
                case "revealTrump" -> rooms.act(playerId, new Action.RevealTrump());
                case "showPair" -> rooms.act(playerId, new Action.ShowPair());
                case "ping" -> sessions.send(connection, Messages.Pong.INSTANCE);
                default -> throw new IllegalMoveException("Unknown message type: " + type);
            }
        } catch (IllegalMoveException | IllegalArgumentException e) {
            sessions.send(connection, new Messages.Error(e.getMessage()));
        } catch (Exception e) {
            sessions.send(connection, new Messages.Error("Bad request"));
        }
    }

    @OnClose
    void onClose(WebSocketConnection connection) {
        String playerId = sessions.unbind(connection);
        if (playerId != null) rooms.disconnected(playerId);
    }

    private void hello(JsonNode msg, WebSocketConnection connection) {
        String playerId = msg.path("playerId").asText("");
        if (playerId.isBlank() || playerId.length() > 64) playerId = UUID.randomUUID().toString();
        String name = cleanName(msg.path("name").asText(""));
        sessions.bind(playerId, name, connection);
        sessions.send(connection, new Messages.Welcome(playerId, name));
        rooms.connected(playerId);
    }

    private static String cleanName(String name) {
        String n = name == null ? "" : name.strip().replaceAll("[\\p{Cntrl}]", "");
        if (n.isEmpty()) n = "Player";
        return n.length() > MAX_NAME ? n.substring(0, MAX_NAME) : n;
    }
}
