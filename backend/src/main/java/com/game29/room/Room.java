package com.game29.room;

import com.game29.bot.Bot;
import com.game29.engine.Action;
import com.game29.engine.Game;
import com.game29.engine.IllegalMoveException;
import com.game29.engine.Phase;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.TimeUnit;

/** One table of four seats. Every public method is synchronized: a room is single-threaded. */
final class Room {

    enum Status { WAITING, PLAYING }

    private static final String[] BOT_NAMES = {"Arjun", "Priya", "Kabir", "Meera", "Ravi", "Anika", "Dev", "Isha"};

    final String code;
    final boolean isPublic;
    private final RoomService service;
    private final Random random = new Random();
    private final Bot bot;
    private final Seat[] seats = new Seat[Game.SEATS];
    private String hostPlayerId;
    private Status status = Status.WAITING;
    private Game game;
    /** Bumped on every change so stale scheduled bot moves are ignored. */
    private long version;
    final long createdAt = System.currentTimeMillis();

    Room(String code, boolean isPublic, RoomService service) {
        this.code = code;
        this.isPublic = isPublic;
        this.service = service;
        this.bot = new Bot(Bot.Level.NORMAL, random);
    }

    synchronized Status status() {
        return status;
    }

    synchronized boolean hasFreeSeat() {
        return status == Status.WAITING && freeSeat() != -1;
    }

    synchronized boolean hasConnectedHumans() {
        for (Seat s : seats) if (s != null && !s.bot && s.connected) return true;
        return false;
    }

    synchronized int seatOf(String playerId) {
        for (int i = 0; i < seats.length; i++) {
            if (seats[i] != null && playerId.equals(seats[i].playerId)) return i;
        }
        return -1;
    }

    /** Seats a human; returns false if the room is full or already playing. */
    synchronized boolean join(String playerId, String name) {
        if (seatOf(playerId) != -1) return true;
        int free = freeSeat();
        if (status != Status.WAITING || free == -1) return false;
        seats[free] = new Seat(playerId, name, false);
        if (hostPlayerId == null) hostPlayerId = playerId;
        changed();
        if (freeSeat() == -1 && isPublic) startGame();
        return true;
    }

    synchronized void addBot(String requester) {
        requireHost(requester);
        int free = freeSeat();
        if (free == -1) throw new IllegalMoveException("Table is full");
        seats[free] = new Seat("bot-" + code + "-" + free, botName(), true);
        changed();
    }

    synchronized void start(String requester) {
        requireHost(requester);
        startGame();
    }

    /** Fill empty seats with bots and deal. */
    synchronized void startGame() {
        if (status != Status.WAITING) return;
        for (int i = 0; i < seats.length; i++) {
            if (seats[i] == null) seats[i] = new Seat("bot-" + code + "-" + i, botName(), true);
        }
        status = Status.PLAYING;
        game = new Game(random);
        changed();
    }

    synchronized void act(String playerId, Action action) {
        if (game == null) throw new IllegalMoveException("Game has not started");
        int seat = seatOf(playerId);
        if (seat == -1) throw new IllegalMoveException("You are not seated here");
        Action.apply(game, seat, action);
        changed();
    }

    synchronized void setConnected(String playerId, boolean connected) {
        int seat = seatOf(playerId);
        if (seat == -1) return;
        seats[seat].connected = connected;
        changed();
    }

    /** A human leaves for good: before the game the seat frees up, during it a bot takes over. */
    synchronized void leave(String playerId) {
        int seat = seatOf(playerId);
        if (seat == -1) return;
        if (status == Status.WAITING) {
            seats[seat] = null;
        } else {
            seats[seat] = new Seat("bot-" + code + "-" + seat, seats[seat].name, true);
        }
        if (playerId.equals(hostPlayerId)) {
            hostPlayerId = null;
            for (Seat s : seats) {
                if (s != null && !s.bot) {
                    hostPlayerId = s.playerId;
                    break;
                }
            }
        }
        changed();
    }

    /** Re-sends everything to one player (after reconnect). */
    synchronized void resend(String playerId) {
        int seat = seatOf(playerId);
        if (seat == -1) return;
        service.outbox().send(playerId, new Messages.RoomMsg(info(seat)));
        if (game != null) service.outbox().send(playerId, new Messages.State(game.view(seat)));
    }

    // ---------------------------------------------------------------- internals

    private void changed() {
        version++;
        broadcast();
        scheduleAutomaticMove();
    }

    private void broadcast() {
        for (int i = 0; i < seats.length; i++) {
            Seat s = seats[i];
            if (s == null || s.bot || !s.connected) continue;
            service.outbox().send(s.playerId, new Messages.RoomMsg(info(i)));
            if (game != null) service.outbox().send(s.playerId, new Messages.State(game.view(i)));
        }
    }

    private void scheduleAutomaticMove() {
        // Nobody watching: pause the table until a human reconnects.
        if (game == null || !hasConnectedHumans()) return;
        long v = version;
        if (game.phase() == Phase.ROUND_OVER) {
            service.scheduler().schedule(() -> nextRound(v), service.config().roundPauseMs(), TimeUnit.MILLISECONDS);
        } else if (game.phase() != Phase.MATCH_OVER && seats[game.turn()].autoPlay()) {
            service.scheduler().schedule(() -> botMove(v), service.config().botDelayMs(), TimeUnit.MILLISECONDS);
        }
    }

    private synchronized void nextRound(long expected) {
        if (expected != version || game.phase() != Phase.ROUND_OVER) return;
        game.nextRound();
        changed();
    }

    private synchronized void botMove(long expected) {
        if (expected != version || game.phase() == Phase.MATCH_OVER) return;
        int seat = game.turn();
        if (seat < 0 || !seats[seat].autoPlay()) return;
        Action.apply(game, seat, bot.decide(game.view(seat)));
        changed();
    }

    private Messages.RoomInfo info(int yourSeat) {
        List<Messages.SeatInfo> list = new ArrayList<>();
        int hostSeat = -1;
        for (int i = 0; i < seats.length; i++) {
            Seat s = seats[i];
            list.add(s == null ? null : new Messages.SeatInfo(i, s.name, s.bot, s.bot || s.connected));
            if (s != null && s.playerId.equals(hostPlayerId)) hostSeat = i;
        }
        return new Messages.RoomInfo(code, isPublic, hostSeat, status.name(), list, yourSeat);
    }

    private int freeSeat() {
        for (int i = 0; i < seats.length; i++) if (seats[i] == null) return i;
        return -1;
    }

    private void requireHost(String playerId) {
        if (!playerId.equals(hostPlayerId)) throw new IllegalMoveException("Only the host can do that");
        if (status != Status.WAITING) throw new IllegalMoveException("Game already started");
    }

    private String botName() {
        List<String> free = new ArrayList<>(List.of(BOT_NAMES));
        for (Seat s : seats) if (s != null) free.remove(s.name.replace(" (bot)", ""));
        return free.get(random.nextInt(free.size())) + " (bot)";
    }
}
