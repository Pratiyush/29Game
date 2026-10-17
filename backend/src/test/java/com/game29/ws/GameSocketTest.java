package com.game29.ws;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.game29.bot.Bot;
import com.game29.engine.Action;
import com.game29.engine.PlayerView;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.websockets.next.BasicWebSocketConnector;
import io.quarkus.websockets.next.WebSocketClientConnection;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.util.Random;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
class GameSocketTest {

    @TestHTTPResource("/")
    URI baseUri;

    @Inject
    ObjectMapper mapper;

    /** A scripted client: it plays its seat with the bot so the round finishes. */
    class Client {
        final BlockingQueue<JsonNode> inbox = new LinkedBlockingQueue<>();
        final WebSocketClientConnection conn;

        Client(String name) throws Exception {
            conn = BasicWebSocketConnector.create()
                    .baseUri(baseUri)
                    .path("/ws")
                    .onTextMessage((c, m) -> {
                        try {
                            inbox.add(mapper.readTree(m));
                        } catch (Exception e) {
                            throw new RuntimeException(e);
                        }
                    })
                    .connectAndAwait();
            send("{\"type\":\"hello\",\"name\":\"" + name + "\"}");
            assertEquals("welcome", next("welcome").path("type").asText());
        }

        void send(String json) {
            conn.sendTextAndAwait(json);
        }

        JsonNode next(String type) throws InterruptedException {
            while (true) {
                JsonNode m = inbox.poll(10, TimeUnit.SECONDS);
                assertNotNull(m, "timed out waiting for " + type);
                if (m.path("type").asText().equals(type)) return m;
                assertNotEquals("error", m.path("type").asText(), m.toString());
            }
        }
    }

    @Test
    void quickMatchFillsWithBotsAndPlaysARound() throws Exception {
        Client c = new Client("Asha");
        c.send("{\"type\":\"quickMatch\"}");
        JsonNode room = c.next("room").path("room");
        assertTrue(room.path("isPublic").asBoolean());
        Bot bot = new Bot(Bot.Level.NORMAL, new Random(1));
        int moves = 0;
        while (true) {
            PlayerView v = mapper.treeToValue(c.next("state").path("view"), PlayerView.class);
            if (v.phase().name().equals("ROUND_OVER") || v.phase().name().equals("MATCH_OVER")) {
                assertEquals(28, v.teamPoints()[0] + v.teamPoints()[1]);
                break;
            }
            if (v.turn() == v.seat() && !v.legal().isEmpty()) {
                Action a = bot.decide(v);
                c.send(toJson(a));
                moves++;
            }
        }
        assertTrue(moves >= 8, "human seat should have played every trick");
        c.conn.closeAndAwait();
    }

    @Test
    void friendsJoinByCodeAndHostStarts() throws Exception {
        Client host = new Client("Host");
        host.send("{\"type\":\"createRoom\"}");
        JsonNode room = host.next("room").path("room");
        String code = room.path("code").asText();
        assertEquals(5, code.length());
        assertFalse(room.path("isPublic").asBoolean());

        Client friend = new Client("Friend");
        friend.send("{\"type\":\"joinRoom\",\"code\":\"" + code.toLowerCase() + "\"}");
        JsonNode joined = friend.next("room").path("room");
        assertEquals(1, joined.path("yourSeat").asInt());

        friend.send("{\"type\":\"startGame\"}");
        assertTrue(friend.next("error").path("message").asText().contains("host"));

        host.send("{\"type\":\"addBot\"}");
        host.send("{\"type\":\"startGame\"}");
        JsonNode state = friend.next("state").path("view");
        assertEquals(4, state.path("hand").size());
        host.conn.closeAndAwait();
        friend.conn.closeAndAwait();
    }

    @Test
    void abandonedFriendRoomIsClosed() throws Exception {
        Client a = new Client("A");
        a.send("{\"type\":\"createRoom\"}");
        JsonNode room = a.next("room").path("room");
        String code = room.path("code").asText();
        a.send("{\"type\":\"leaveRoom\"}");
        a.next("left");

        Client b = new Client("B");
        b.send("{\"type\":\"joinRoom\",\"code\":\"" + code + "\"}");
        assertTrue(b.next("error").path("message").asText().contains(code));
    }

    private static String toJson(Action a) {
        return switch (a) {
            case Action.Bid b -> "{\"type\":\"bid\",\"value\":" + b.value() + "}";
            case Action.Pass p -> "{\"type\":\"pass\"}";
            case Action.ChooseTrump t -> "{\"type\":\"chooseTrump\",\"card\":\"" + t.card().code() + "\"}";
            case Action.Play p -> "{\"type\":\"play\",\"card\":\"" + p.card().code() + "\"}";
            case Action.RevealTrump r -> "{\"type\":\"revealTrump\"}";
            case Action.ShowPair s -> "{\"type\":\"showPair\"}";
        };
    }
}
