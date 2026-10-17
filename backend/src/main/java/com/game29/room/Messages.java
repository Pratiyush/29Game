package com.game29.room;

import com.game29.engine.PlayerView;

import java.util.List;

/** Server -> client messages. Field names are the wire format (docs/PROTOCOL.md). */
public final class Messages {
    private Messages() {}

    public record Welcome(String type, String playerId, String name) {
        public Welcome(String playerId, String name) {
            this("welcome", playerId, name);
        }
    }

    public record SeatInfo(int seat, String name, boolean bot, boolean connected, int avatar) {}

    public record RoomInfo(String code, boolean isPublic, int hostSeat, String status, List<SeatInfo> seats, int yourSeat) {}

    public record RoomMsg(String type, RoomInfo room) {
        public RoomMsg(RoomInfo room) {
            this("room", room);
        }
    }

    public record State(String type, PlayerView view) {
        public State(PlayerView view) {
            this("state", view);
        }
    }

    public record Error(String type, String message) {
        public Error(String message) {
            this("error", message);
        }
    }

    /** A quick reaction from a seat, shown as a bubble over its avatar. */
    public record Emote(String type, int seat, String emote) {
        public Emote(int seat, String emote) {
            this("emote", seat, emote);
        }
    }

    public record Pong(String type) {
        public static final Pong INSTANCE = new Pong("pong");
    }

    public record Left(String type) {
        public static final Left INSTANCE = new Left("left");
    }
}
