package com.game29.bot;

import com.game29.engine.Action;
import com.game29.engine.Card;
import com.game29.engine.Game;
import com.game29.engine.PlayerView;
import com.game29.engine.Rank;
import com.game29.engine.Suit;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * Rule-based 29 bot. It only sees its own {@link PlayerView}, so it plays fair.
 * Strategy summary (see docs/BOTS.md):
 * <ul>
 *   <li>Bid from hand strength: card points + length of the best suit.</li>
 *   <li>Pick the longest/strongest suit as trump and hide its lowest card.</li>
 *   <li>Track played cards to know which cards are "masters" (can no longer be beaten).</li>
 *   <li>Lead masters to cash points, otherwise lead low; draw trumps once revealed if our side bid.</li>
 *   <li>Feed points to a partner who is safely winning; win cheaply; otherwise throw the cheapest card.</li>
 *   <li>Ask for trump when void and the opponents are taking points.</li>
 * </ul>
 * The Dart port in app/lib/engine/bot.dart must stay in sync.
 */
public final class Bot {

    public enum Level { EASY, NORMAL }

    private final Level level;
    private final Random random;

    public Bot(Level level, Random random) {
        this.level = level;
        this.random = random;
    }

    public Action decide(PlayerView v) {
        PlayerView.Legal legal = v.legal();
        if (legal.canShowPair()) return new Action.ShowPair();
        return switch (v.phase()) {
            case BIDDING -> level == Level.EASY ? easyBid(legal) : bid(v);
            case CHOOSE_TRUMP -> chooseTrump(v);
            case PLAYING -> level == Level.EASY
                    ? new Action.Play(Card.parse(legal.cards().get(random.nextInt(legal.cards().size()))))
                    : play(v);
            default -> throw new IllegalStateException("Bot asked to act in " + v.phase());
        };
    }

    // ---------------------------------------------------------------- bidding

    private Action easyBid(PlayerView.Legal legal) {
        if (legal.canPass() && random.nextInt(3) > 0) return new Action.Pass();
        return new Action.Bid(legal.bids().get(0));
    }

    private Action bid(PlayerView v) {
        PlayerView.Legal legal = v.legal();
        if (!legal.canPass()) return new Action.Bid(legal.bids().get(0));
        if (legal.bids().isEmpty()) return new Action.Pass();
        int min = legal.bids().get(0);
        int estimate = estimate(cards(v.hand()));
        boolean partnerLeads = v.bidder() != -1 && Game.teamOf(v.bidder()) == Game.teamOf(v.seat());
        // Don't fight the partner for the contract unless clearly stronger.
        if (partnerLeads && estimate < min + 2) return new Action.Pass();
        return min <= estimate ? new Action.Bid(min) : new Action.Pass();
    }

    /** Highest bid this four-card hand is worth. */
    static int estimate(List<Card> hand) {
        int points = 0;
        boolean hasJack = false;
        int[] perSuit = new int[4];
        for (Card c : hand) {
            points += c.points();
            perSuit[c.suit().ordinal()]++;
            if (c.rank() == Rank.JACK) hasJack = true;
        }
        int longest = 0;
        for (int n : perSuit) longest = Math.max(longest, n);
        int est = 12 + points + longest - (hasJack ? 0 : 1);
        return Math.min(est, Game.MAX_BID);
    }

    private Action chooseTrump(PlayerView v) {
        List<Card> options = cards(v.legal().trumpCards());
        Suit best = null;
        int bestScore = Integer.MIN_VALUE;
        for (Suit s : Suit.values()) {
            int score = 0;
            for (Card c : options) {
                if (c.suit() != s) continue;
                score += 3 + c.points() + (c.rank() == Rank.JACK ? 2 : 0);
            }
            if (score > bestScore) {
                bestScore = score;
                best = s;
            }
        }
        Suit trump = best;
        Card hide = options.stream().filter(c -> c.suit() == trump)
                .min(Comparator.comparingInt(c -> c.rank().power)).orElseThrow();
        return new Action.ChooseTrump(hide);
    }

    // ---------------------------------------------------------------- card play

    private Action play(PlayerView v) {
        PlayerView.Legal legal = v.legal();
        List<Card> options = cards(legal.cards());
        Knowledge k = new Knowledge(v);
        if (v.trick().isEmpty()) return new Action.Play(lead(v, options, k));

        Suit led = Card.parse(v.trick().get(0).card()).suit();
        Suit effectiveTrump = v.trumpRevealed() ? k.trump : null;
        int winnerSeat = Game.winnerOf(v.trick(), effectiveTrump);
        Card winning = cardOf(v.trick(), winnerSeat);
        boolean partnerWinning = Game.teamOf(winnerSeat) == Game.teamOf(v.seat());
        boolean last = v.trick().size() == Game.SEATS - 1;
        int trickPoints = v.trick().stream().mapToInt(p -> Card.parse(p.card()).points()).sum();
        boolean partnerSafe = partnerWinning && (last
                || (k.isMaster(winning) && (winning.suit() == effectiveTrump || !k.trumpThreat(led))));

        boolean following = options.stream().anyMatch(c -> c.suit() == led);
        if (following) {
            if (partnerWinning) return new Action.Play(partnerSafe ? feed(options, k) : lowest(options, k));
            List<Card> winners = options.stream().filter(c -> Game.beats(c, winning, effectiveTrump)).toList();
            if (winners.isEmpty()) return new Action.Play(lowest(options, k));
            if (last) return new Action.Play(cheapest(winners));
            List<Card> masters = winners.stream().filter(k::isMaster).toList();
            if (!masters.isEmpty() && !k.trumpThreat(led)) return new Action.Play(cheapest(masters));
            return new Action.Play(lowest(options, k));
        }

        // Void in the led suit.
        if (partnerSafe) return new Action.Play(feed(options, k));
        if (legal.canRevealTrump() && !partnerWinning && (trickPoints >= 1 || !last)) {
            boolean bidderWithoutTrumps = v.seat() == v.bidder() && k.trumpsHeld() == 0;
            if (!bidderWithoutTrumps || trickPoints >= 2) return new Action.RevealTrump();
        }
        if (v.trumpRevealed() && !partnerWinning) {
            List<Card> trumpWinners = options.stream()
                    .filter(c -> c.suit() == k.trump && Game.beats(c, winning, k.trump)).toList();
            if (!trumpWinners.isEmpty()) {
                if (last || trickPoints == 0) return new Action.Play(cheapest(trumpWinners));
                List<Card> masters = trumpWinners.stream().filter(k::isMaster).toList();
                return new Action.Play(cheapest(masters.isEmpty() ? trumpWinners : masters));
            }
        }
        return new Action.Play(lowest(options, k));
    }

    private Card lead(PlayerView v, List<Card> options, Knowledge k) {
        boolean ourContract = v.bidder() != -1 && Game.teamOf(v.bidder()) == Game.teamOf(v.seat());
        if (v.trumpRevealed() && ourContract && k.unseen(k.trump) > 0) {
            List<Card> masterTrumps = options.stream().filter(c -> c.suit() == k.trump && k.isMaster(c)).toList();
            if (!masterTrumps.isEmpty()) return masterTrumps.get(0);
        }
        List<Card> plain = options.stream().filter(c -> c.suit() != k.trump).toList();
        if (plain.isEmpty()) plain = options;
        List<Card> cashable = plain.stream().filter(c -> k.isMaster(c) && c.points() > 0).toList();
        if (!cashable.isEmpty()) {
            return cashable.stream().max(Comparator.comparingInt(Card::points)).orElseThrow();
        }
        // Lead low from a suit where we hold no unprotected point cards.
        return plain.stream().min(Comparator
                .comparingInt((Card c) -> exposedPoints(c.suit(), options, k))
                .thenComparingInt(Card::points)
                .thenComparingInt(c -> c.rank().power)).orElseThrow();
    }

    /** Points we hold in this suit that could still be captured by a higher unseen card. */
    private static int exposedPoints(Suit s, List<Card> hand, Knowledge k) {
        int n = 0;
        for (Card c : hand) if (c.suit() == s && !k.isMaster(c)) n += c.points();
        return n;
    }

    /** Give points to a partner who is winning: the most valuable card we would not win with later. */
    private static Card feed(List<Card> options, Knowledge k) {
        List<Card> candidates = options.stream()
                .filter(c -> c.suit() != k.trump && !k.isMaster(c) && c.points() > 0).toList();
        if (candidates.isEmpty()) return lowest(options, k);
        return candidates.stream().max(Comparator.comparingInt(Card::points)
                .thenComparingInt(c -> -c.rank().power)).orElseThrow();
    }

    /** The card we lose least by giving away: no points, low rank, preferably not trump. */
    private static Card lowest(List<Card> options, Knowledge k) {
        return options.stream().min(Comparator
                .comparingInt((Card c) -> c.suit() == k.trump ? 1 : 0)
                .thenComparingInt(Card::points)
                .thenComparingInt(c -> c.rank().power)).orElseThrow();
    }

    private static Card cheapest(List<Card> winners) {
        return winners.stream().min(Comparator.comparingInt((Card c) -> c.rank().power)).orElseThrow();
    }

    private static Card cardOf(List<PlayerView.Play> trick, int seat) {
        return trick.stream().filter(p -> p.seat() == seat).map(p -> Card.parse(p.card())).findFirst().orElseThrow();
    }

    private static List<Card> cards(List<String> codes) {
        List<Card> out = new ArrayList<>(codes.size());
        for (String c : codes) out.add(Card.parse(c));
        return out;
    }

    /** What this seat can deduce: cards it has seen and the trump suit if known. */
    private static final class Knowledge {
        final Suit trump;
        final Set<Card> seen = new HashSet<>();
        final List<Card> hand;

        Knowledge(PlayerView v) {
            trump = v.trump() == null ? null : Suit.fromCode(v.trump().charAt(0));
            hand = cards(v.hand());
            seen.addAll(hand);
            seen.addAll(cards(v.played()));
            v.trick().forEach(p -> seen.add(Card.parse(p.card())));
            if (v.hiddenTrump() != null) seen.add(Card.parse(v.hiddenTrump()));
        }

        boolean isMaster(Card c) {
            for (Card other : Card.deck()) {
                if (other.suit() == c.suit() && other.rank().power > c.rank().power && !seen.contains(other)) {
                    return false;
                }
            }
            return true;
        }

        int unseen(Suit s) {
            if (s == null) return 0;
            int n = 0;
            for (Card c : Card.deck()) if (c.suit() == s && !seen.contains(c)) n++;
            return n;
        }

        int trumpsHeld() {
            if (trump == null) return 0;
            return (int) hand.stream().filter(c -> c.suit() == trump).count();
        }

        /** Could an opponent still ruff this suit? Rough: a known trump suit with cards outstanding. */
        boolean trumpThreat(Suit led) {
            return trump != null && led != trump && unseen(trump) > 0 && unseen(led) <= 2;
        }
    }
}
