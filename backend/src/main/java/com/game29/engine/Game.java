package com.game29.engine;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * Authoritative 29 rules for one match between four seats. Seats 0 and 2 form team 0,
 * seats 1 and 3 form team 1. Not thread safe: callers serialise access (one room = one lock).
 * See docs/RULES.md for the exact variant implemented. The Dart port in
 * app/lib/engine/game.dart must stay in sync with this class.
 */
public class Game {

    public static final int SEATS = 4;
    public static final int MIN_BID = 16;
    public static final int MAX_BID = 28;
    public static final int PAIR_BONUS = 4;
    public static final int MATCH_POINTS_TO_WIN = 6;
    public static final int TRICKS_PER_ROUND = 8;

    private final Random random;

    private Phase phase = Phase.BIDDING;
    private int round = 0;
    private int dealer;
    private int turn = -1;

    private final List<List<Card>> hands = new ArrayList<>();
    private final List<Card> stock = new ArrayList<>();

    // Bidding
    private final List<PlayerView.Bid> bids = new ArrayList<>();
    private final boolean[] passed = new boolean[SEATS];
    private int highestBid;
    private int bidder = -1;

    // Trump
    private Suit trump;
    private Card hiddenTrump;
    private boolean trumpRevealed;
    private int revealedThisTrickBy = -1;

    // Play
    private final List<PlayerView.Play> trick = new ArrayList<>();
    private List<PlayerView.Play> lastTrick = List.of();
    private int lastTrickWinner = -1;
    private final List<Card> played = new ArrayList<>();
    private final int[] teamPoints = new int[2];
    private final boolean[] wonTrickAfterReveal = new boolean[2];
    private int tricksPlayed;
    private int target;
    private int pairShownBy = -1;

    // Match
    private final int[] matchScore = new int[2];
    private PlayerView.RoundResult lastRound;
    private int matchWinner = -1;

    public Game(Random random) {
        this(random, random.nextInt(SEATS));
    }

    public Game(Random random, int firstDealer) {
        this.random = random;
        this.dealer = (firstDealer + SEATS - 1) % SEATS; // startRound advances it
        for (int i = 0; i < SEATS; i++) hands.add(new ArrayList<>());
        startRound();
    }

    public static int teamOf(int seat) {
        return seat % 2;
    }

    public static int next(int seat) {
        return (seat + 1) % SEATS;
    }

    // ---------------------------------------------------------------- round lifecycle

    private void startRound() {
        round++;
        dealer = next(dealer);
        phase = Phase.BIDDING;
        hands.forEach(List::clear);
        stock.clear();
        bids.clear();
        java.util.Arrays.fill(passed, false);
        highestBid = 0;
        bidder = -1;
        trump = null;
        hiddenTrump = null;
        trumpRevealed = false;
        revealedThisTrickBy = -1;
        trick.clear();
        lastTrick = List.of();
        lastTrickWinner = -1;
        played.clear();
        teamPoints[0] = teamPoints[1] = 0;
        wonTrickAfterReveal[0] = wonTrickAfterReveal[1] = false;
        tricksPlayed = 0;
        target = 0;
        pairShownBy = -1;

        List<Card> deck = new ArrayList<>(Card.deck());
        Collections.shuffle(deck, random);
        stock.addAll(deck);
        dealCards(4);
        turn = next(dealer);
    }

    private void dealCards(int perSeat) {
        for (int i = 0; i < perSeat; i++) {
            for (int s = 1; s <= SEATS; s++) {
                hands.get((dealer + s) % SEATS).add(stock.remove(stock.size() - 1));
            }
        }
    }

    /** Called by the host after a ROUND_OVER pause. */
    public void nextRound() {
        if (phase != Phase.ROUND_OVER) throw new IllegalMoveException("Round is not over");
        startRound();
    }

    // ---------------------------------------------------------------- actions

    public void bid(int seat, int value) {
        requireTurn(seat, Phase.BIDDING);
        if (value < Math.max(MIN_BID, highestBid + 1) || value > MAX_BID) {
            throw new IllegalMoveException("Bid must be between " + Math.max(MIN_BID, highestBid + 1) + " and " + MAX_BID);
        }
        bids.add(new PlayerView.Bid(seat, value));
        highestBid = value;
        bidder = seat;
        advanceBidding();
    }

    public void pass(int seat) {
        requireTurn(seat, Phase.BIDDING);
        if (!canPass(seat)) throw new IllegalMoveException("Everyone else passed: you must bid");
        bids.add(new PlayerView.Bid(seat, null));
        passed[seat] = true;
        advanceBidding();
    }

    private boolean canPass(int seat) {
        return !(bidder == -1 && passedCount() == SEATS - 1);
    }

    private int passedCount() {
        int n = 0;
        for (boolean p : passed) if (p) n++;
        return n;
    }

    private void advanceBidding() {
        if (bidder != -1 && (passedCount() == SEATS - 1 || highestBid == MAX_BID)) {
            phase = Phase.CHOOSE_TRUMP;
            turn = bidder;
            return;
        }
        int s = next(turn);
        while (passed[s]) s = next(s);
        turn = s;
    }

    /** The bidder picks one of their four cards; its suit becomes trump and it stays face down. */
    public void chooseTrump(int seat, Card card) {
        requireTurn(seat, Phase.CHOOSE_TRUMP);
        List<Card> hand = hands.get(seat);
        if (!hand.remove(card)) throw new IllegalMoveException("You do not hold " + card);
        hiddenTrump = card;
        trump = card.suit();
        target = highestBid;
        dealCards(4);
        phase = Phase.PLAYING;
        turn = next(dealer);
        autoRevealIfNeeded();
    }

    /** A player unable to follow suit asks for the trump to be revealed. */
    public void revealTrump(int seat) {
        requireTurn(seat, Phase.PLAYING);
        if (!canRevealTrump(seat)) throw new IllegalMoveException("You cannot ask for trump now");
        doReveal(seat);
    }

    private void doReveal(int seat) {
        trumpRevealed = true;
        revealedThisTrickBy = seat;
        hands.get(bidder).add(hiddenTrump);
        hiddenTrump = null;
    }

    public void showPair(int seat) {
        requireTurn(seat, Phase.PLAYING);
        if (!canShowPair(seat)) throw new IllegalMoveException("You cannot show a pair now");
        pairShownBy = seat;
        if (teamOf(seat) == teamOf(bidder)) {
            target = Math.max(MIN_BID, target - PAIR_BONUS);
        } else {
            target = Math.min(MAX_BID, target + PAIR_BONUS);
        }
    }

    public void play(int seat, Card card) {
        requireTurn(seat, Phase.PLAYING);
        if (!legalCards(seat).contains(card)) throw new IllegalMoveException("You cannot play " + card + " now");
        hands.get(seat).remove(card);
        trick.add(new PlayerView.Play(seat, card.code()));
        if (trick.size() < SEATS) {
            turn = next(seat);
            autoRevealIfNeeded();
            return;
        }
        int winner = currentWinner();
        int team = teamOf(winner);
        for (PlayerView.Play p : trick) {
            Card c = Card.parse(p.card());
            teamPoints[team] += c.points();
            played.add(c);
        }
        if (trumpRevealed) wonTrickAfterReveal[team] = true;
        lastTrick = List.copyOf(trick);
        lastTrickWinner = winner;
        trick.clear();
        revealedThisTrickBy = -1;
        tricksPlayed++;
        if (tricksPlayed == TRICKS_PER_ROUND) {
            endRound();
        } else {
            turn = winner;
            autoRevealIfNeeded();
        }
    }

    /** The bidder's last card may be the face-down trump; it is revealed when they must play it. */
    private void autoRevealIfNeeded() {
        if (phase == Phase.PLAYING && !trumpRevealed && turn == bidder && hands.get(bidder).isEmpty()) {
            doReveal(bidder);
        }
    }

    private void endRound() {
        int bidderTeam = teamOf(bidder);
        boolean success = teamPoints[bidderTeam] >= target;
        int delta = success ? 1 : -1;
        matchScore[bidderTeam] += delta;
        lastRound = new PlayerView.RoundResult(bidder, highestBid, target, teamPoints[bidderTeam], success, delta);
        turn = -1;
        phase = Phase.ROUND_OVER;
        for (int t = 0; t < 2; t++) {
            if (matchScore[t] >= MATCH_POINTS_TO_WIN) matchWinner = t;
            else if (matchScore[t] <= -MATCH_POINTS_TO_WIN) matchWinner = 1 - t;
        }
        if (matchWinner != -1) phase = Phase.MATCH_OVER;
    }

    private void requireTurn(int seat, Phase expected) {
        if (phase != expected) throw new IllegalMoveException("Not allowed during " + phase);
        if (seat != turn) throw new IllegalMoveException("Not your turn");
    }

    // ---------------------------------------------------------------- rules queries

    public List<Card> legalCards(int seat) {
        if (phase != Phase.PLAYING || seat != turn) return List.of();
        List<Card> hand = hands.get(seat);
        if (trick.isEmpty()) return List.copyOf(hand);
        Suit led = Card.parse(trick.get(0).card()).suit();
        List<Card> follow = hand.stream().filter(c -> c.suit() == led).toList();
        if (!follow.isEmpty()) return follow;
        if (trumpRevealed && revealedThisTrickBy == seat) {
            List<Card> trumps = hand.stream().filter(c -> c.suit() == trump).toList();
            if (!trumps.isEmpty()) return trumps;
        }
        return List.copyOf(hand);
    }

    public boolean canRevealTrump(int seat) {
        if (phase != Phase.PLAYING || seat != turn || trumpRevealed || trick.isEmpty()) return false;
        Suit led = Card.parse(trick.get(0).card()).suit();
        return hands.get(seat).stream().noneMatch(c -> c.suit() == led);
    }

    public boolean canShowPair(int seat) {
        if (phase != Phase.PLAYING || seat != turn || !trumpRevealed || pairShownBy != -1) return false;
        if (!wonTrickAfterReveal[teamOf(seat)]) return false;
        List<Card> hand = hands.get(seat);
        return hand.contains(new Card(Rank.KING, trump)) && hand.contains(new Card(Rank.QUEEN, trump));
    }

    /** Seat currently winning the trick in progress (-1 if empty). Trump only counts once revealed. */
    public int currentWinner() {
        return winnerOf(trick, trumpRevealed ? trump : null);
    }

    public static int winnerOf(List<PlayerView.Play> trick, Suit effectiveTrump) {
        if (trick.isEmpty()) return -1;
        PlayerView.Play best = trick.get(0);
        for (int i = 1; i < trick.size(); i++) {
            PlayerView.Play p = trick.get(i);
            if (beats(Card.parse(p.card()), Card.parse(best.card()), effectiveTrump)) best = p;
        }
        return best.seat();
    }

    /** Does challenger beat the current best card? (best is always led suit or trump) */
    public static boolean beats(Card challenger, Card best, Suit trump) {
        if (trump != null) {
            if (challenger.suit() == trump && best.suit() != trump) return true;
            if (best.suit() == trump && challenger.suit() != trump) return false;
        }
        return challenger.suit() == best.suit() && challenger.rank().power > best.rank().power;
    }

    // ---------------------------------------------------------------- views

    public PlayerView view(int seat) {
        boolean seesTrump = trump != null && (trumpRevealed || seat == bidder);
        int[] counts = new int[SEATS];
        for (int s = 0; s < SEATS; s++) counts[s] = hands.get(s).size() + (s == bidder && hiddenTrump != null ? 1 : 0);
        return new PlayerView(
                seat,
                phase,
                round,
                dealer,
                turn,
                codes(sortedHand(seat)),
                seat == bidder && hiddenTrump != null ? hiddenTrump.code() : null,
                seesTrump ? String.valueOf(trump.code) : null,
                trumpRevealed,
                List.copyOf(bids),
                highestBid,
                bidder,
                target,
                List.copyOf(trick),
                lastTrick,
                lastTrickWinner,
                codes(played),
                teamPoints.clone(),
                matchScore.clone(),
                counts,
                pairShownBy,
                tricksPlayed,
                lastRound,
                matchWinner,
                legal(seat));
    }

    private PlayerView.Legal legal(int seat) {
        if (seat != turn) return PlayerView.Legal.NONE;
        return switch (phase) {
            case BIDDING -> {
                List<Integer> b = new ArrayList<>();
                for (int v = Math.max(MIN_BID, highestBid + 1); v <= MAX_BID; v++) b.add(v);
                yield new PlayerView.Legal(b, canPass(seat), List.of(), List.of(), false, false);
            }
            case CHOOSE_TRUMP -> new PlayerView.Legal(List.of(), false, codes(hands.get(seat)), List.of(), false, false);
            case PLAYING -> new PlayerView.Legal(List.of(), false, List.of(), codes(legalCards(seat)),
                    canRevealTrump(seat), canShowPair(seat));
            default -> PlayerView.Legal.NONE;
        };
    }

    private List<Card> sortedHand(int seat) {
        List<Card> h = new ArrayList<>(hands.get(seat));
        h.sort((a, b) -> a.suit() != b.suit() ? a.suit().compareTo(b.suit()) : b.rank().power - a.rank().power);
        return h;
    }

    private static List<String> codes(List<Card> cards) {
        return cards.stream().map(Card::code).toList();
    }

    // ---------------------------------------------------------------- accessors (host / tests)

    public Phase phase() { return phase; }
    public int turn() { return turn; }
    public int bidder() { return bidder; }
    public int round() { return round; }
    public int tricksPlayed() { return tricksPlayed; }
    public boolean trickEmpty() { return trick.isEmpty(); }
    public int[] teamPoints() { return teamPoints.clone(); }
    public int[] matchScore() { return matchScore.clone(); }
    public List<Card> hand(int seat) { return List.copyOf(hands.get(seat)); }
}
