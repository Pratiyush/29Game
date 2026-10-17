package com.game29.engine;

import com.game29.bot.Bot;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class GameTest {

    @Test
    void dealsFourCardsEachAndFirstBidderIsLeftOfDealer() {
        Game g = new Game(new Random(1), 0);
        assertEquals(Phase.BIDDING, g.phase());
        assertEquals(1, g.turn());
        for (int s = 0; s < 4; s++) assertEquals(4, g.hand(s).size());
    }

    @Test
    void lastPlayerIsForcedToBidWhenEveryonePasses() {
        Game g = new Game(new Random(1), 0);
        g.pass(1);
        g.pass(2);
        g.pass(3);
        assertFalse(g.view(0).legal().canPass());
        assertThrows(IllegalMoveException.class, () -> g.pass(0));
        g.bid(0, 16);
        assertEquals(Phase.CHOOSE_TRUMP, g.phase());
        assertEquals(0, g.bidder());
    }

    @Test
    void biddingSkipsPassedPlayersAndEndsWithHighest() {
        Game g = new Game(new Random(1), 0);
        g.bid(1, 16);
        g.bid(2, 17);
        g.pass(3);
        g.pass(0);
        g.bid(1, 18);
        assertEquals(2, g.turn());
        g.pass(2);
        assertEquals(Phase.CHOOSE_TRUMP, g.phase());
        assertEquals(1, g.bidder());
        assertThrows(IllegalMoveException.class, () -> g.bid(1, 19));
    }

    @Test
    void trumpIsHiddenFromOthersUntilRevealed() {
        Game g = new Game(new Random(3), 0);
        g.bid(1, 16);
        g.pass(2);
        g.pass(3);
        g.pass(0);
        Card hide = g.hand(1).get(0);
        g.chooseTrump(1, hide);
        assertEquals(7, g.hand(1).size());
        assertEquals(8, g.view(1).handCounts()[1]);
        assertEquals(hide.code(), g.view(1).hiddenTrump());
        assertNotNull(g.view(1).trump());
        assertNull(g.view(0).trump());
        assertNull(g.view(0).hiddenTrump());
        assertEquals(Phase.PLAYING, g.phase());
    }

    @Test
    void trickWinnerRespectsTrumpOnlyWhenRevealed() {
        List<PlayerView.Play> trick = List.of(
                new PlayerView.Play(0, "7H"),
                new PlayerView.Play(1, "JH"),
                new PlayerView.Play(2, "7S"),
                new PlayerView.Play(3, "9H"));
        assertEquals(1, Game.winnerOf(trick, null));
        assertEquals(2, Game.winnerOf(trick, Suit.SPADES));
        assertEquals(1, Game.winnerOf(trick, Suit.CLUBS));
    }

    @Test
    void cardPointsTotal28() {
        assertEquals(28, Card.deck().stream().mapToInt(Card::points).sum());
    }

    /** Plays thousands of bot-only rounds checking invariants, the same way a server room would. */
    @Test
    void botsCompleteManyMatchesWithoutIllegalMoves() {
        Random rnd = new Random(42);
        for (int match = 0; match < 200; match++) {
            Bot.Level level = match % 3 == 0 ? Bot.Level.EASY : Bot.Level.NORMAL;
            Bot bot = new Bot(level, rnd);
            Game g = new Game(rnd);
            int rounds = 0;
            while (g.phase() != Phase.MATCH_OVER && rounds < 500) {
                if (g.phase() == Phase.ROUND_OVER) {
                    g.nextRound();
                    rounds++;
                    continue;
                }
                int seat = g.turn();
                PlayerView v = g.view(seat);
                assertFalse(v.legal().isEmpty(), "seat to move must have a legal action");
                if (g.phase() == Phase.PLAYING) assertCardsConserved(g);
                Action.apply(g, seat, bot.decide(v));
                if (g.phase() == Phase.ROUND_OVER || g.phase() == Phase.MATCH_OVER) {
                    int[] pts = g.view(0).teamPoints();
                    assertEquals(28, pts[0] + pts[1]);
                }
            }
            assertEquals(Phase.MATCH_OVER, g.phase());
            assertNotEquals(-1, g.view(0).matchWinner());
        }
    }

    @Test
    void normalBotsBeatRandomBots() {
        Random rnd = new Random(7);
        Bot smart = new Bot(Bot.Level.NORMAL, rnd);
        Bot dumb = new Bot(Bot.Level.EASY, rnd);
        int smartPoints = 0, dumbPoints = 0;
        for (int i = 0; i < 400; i++) {
            Game g = new Game(rnd);
            while (g.phase() != Phase.ROUND_OVER && g.phase() != Phase.MATCH_OVER) {
                int seat = g.turn();
                Bot b = Game.teamOf(seat) == 0 ? smart : dumb;
                Action.apply(g, seat, b.decide(g.view(seat)));
            }
            smartPoints += g.teamPoints()[0];
            dumbPoints += g.teamPoints()[1];
        }
        assertTrue(smartPoints > dumbPoints * 1.2,
                "normal bots should take clearly more card points: " + smartPoints + " vs " + dumbPoints);
    }

    private static void assertCardsConserved(Game g) {
        PlayerView v = g.view(0);
        Set<String> all = new HashSet<>(v.played());
        v.trick().forEach(p -> all.add(p.card()));
        int inHands = 0;
        for (int s = 0; s < 4; s++) inHands += v.handCounts()[s];
        assertEquals(32, all.size() + inHands);
    }
}
