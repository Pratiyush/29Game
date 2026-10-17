package com.game29.room;

import com.game29.engine.Action;
import com.game29.engine.IllegalMoveException;
import io.quarkus.runtime.ShutdownEvent;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;

import java.security.SecureRandom;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/** In-memory registry of rooms, quick-match pairing and friend rooms (by code). */
@ApplicationScoped
public class RoomService {

    private static final String CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    @Inject
    GameConfig config;

    @Inject
    Outbox outbox;

    private final SecureRandom random = new SecureRandom();
    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    private final Map<String, String> roomOfPlayer = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2, r -> {
        Thread t = new Thread(r, "game29-scheduler");
        t.setDaemon(true);
        return t;
    });

    void onStart(@Observes StartupEvent ev) {
        scheduler.scheduleAtFixedRate(this::evictIdleRooms, 1, 1, TimeUnit.MINUTES);
    }

    void onStop(@Observes ShutdownEvent ev) {
        scheduler.shutdownNow();
    }

    GameConfig config() { return config; }
    Outbox outbox() { return outbox; }
    ScheduledExecutorService scheduler() { return scheduler; }

    // ---------------------------------------------------------------- lobby

    /** Joins the oldest public table with a free seat, or opens one that fills with bots after a short wait. */
    public synchronized void quickMatch(String playerId, String name) {
        leave(playerId);
        Room target = rooms.values().stream()
                .filter(r -> r.isPublic && r.hasFreeSeat())
                .min((a, b) -> Long.compare(a.createdAt, b.createdAt))
                .orElse(null);
        if (target == null) {
            target = newRoom(true);
            Room room = target;
            scheduler.schedule(() -> {
                if (rooms.containsKey(room.code)) room.startGame();
            }, config.quickMatchWaitMs(), TimeUnit.MILLISECONDS);
        }
        seat(target, playerId, name);
    }

    public synchronized String createRoom(String playerId, String name) {
        leave(playerId);
        Room room = newRoom(false);
        seat(room, playerId, name);
        return room.code;
    }

    public synchronized void joinRoom(String playerId, String name, String code) {
        Room room = rooms.get(code == null ? "" : code.trim().toUpperCase());
        if (room == null) throw new IllegalMoveException("No table with code " + code);
        if (room.seatOf(playerId) != -1) {
            room.setConnected(playerId, true);
            return;
        }
        if (!room.hasFreeSeat()) throw new IllegalMoveException("That table is full or already playing");
        leave(playerId);
        seat(room, playerId, name);
    }

    public void addBot(String playerId) {
        roomOf(playerId).addBot(playerId);
    }

    public void start(String playerId) {
        roomOf(playerId).start(playerId);
    }

    public void act(String playerId, Action action) {
        roomOf(playerId).act(playerId, action);
    }

    public synchronized void leave(String playerId) {
        String code = roomOfPlayer.remove(playerId);
        if (code == null) return;
        Room room = rooms.get(code);
        if (room == null) return;
        room.leave(playerId);
        if (!room.hasConnectedHumans()) rooms.remove(code);
    }

    // ---------------------------------------------------------------- connection lifecycle

    /** Player (re)connected: if they were seated, give them their seat back and resend the table. */
    public void connected(String playerId) {
        Room room = currentRoom(playerId);
        if (room == null) return;
        room.setConnected(playerId, true);
        room.resend(playerId);
    }

    public void disconnected(String playerId) {
        Room room = currentRoom(playerId);
        if (room != null) room.setConnected(playerId, false);
    }

    public int roomCount() {
        return rooms.size();
    }

    // ---------------------------------------------------------------- internals

    private void seat(Room room, String playerId, String name) {
        roomOfPlayer.put(playerId, room.code);
        if (!room.join(playerId, name)) {
            roomOfPlayer.remove(playerId);
            throw new IllegalMoveException("Could not take a seat");
        }
    }

    private Room newRoom(boolean isPublic) {
        String code;
        do {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 5; i++) sb.append(CODE_CHARS.charAt(random.nextInt(CODE_CHARS.length())));
            code = sb.toString();
        } while (rooms.containsKey(code));
        Room room = new Room(code, isPublic, this);
        rooms.put(code, room);
        return room;
    }

    private Room currentRoom(String playerId) {
        String code = roomOfPlayer.get(playerId);
        return code == null ? null : rooms.get(code);
    }

    private Room roomOf(String playerId) {
        Room room = currentRoom(playerId);
        if (room == null) throw new IllegalMoveException("You are not at a table");
        return room;
    }

    private synchronized void evictIdleRooms() {
        long cutoff = System.currentTimeMillis() - config.idleRoomTtlMs();
        rooms.values().removeIf(r -> r.createdAt < cutoff && !r.hasConnectedHumans());
        roomOfPlayer.values().removeIf(code -> !rooms.containsKey(code));
    }
}
