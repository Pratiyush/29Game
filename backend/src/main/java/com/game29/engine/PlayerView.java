package com.game29.engine;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.util.List;

/**
 * Everything one seat is allowed to see, plus its legal moves. This is the only game state
 * sent to clients and the only input bots get, so bots can never cheat.
 * The JSON shape is shared with the Flutter client (see docs/PROTOCOL.md).
 */
public record PlayerView(
        int seat,
        Phase phase,
        int round,
        int dealer,
        int turn,
        List<String> hand,
        String hiddenTrump,
        String trump,
        boolean trumpRevealed,
        List<Bid> bids,
        int highestBid,
        int bidder,
        int target,
        List<Play> trick,
        List<Play> lastTrick,
        int lastTrickWinner,
        List<String> played,
        int[] teamPoints,
        int[] matchScore,
        int[] handCounts,
        int pairShownBy,
        int tricksPlayed,
        RoundResult lastRound,
        int matchWinner,
        Legal legal) {

    /** value == null means pass. */
    public record Bid(int seat, Integer value) {}

    public record Play(int seat, String card) {}

    public record RoundResult(int bidder, int bid, int target, int bidderTeamPoints, boolean success, int delta) {}

    public record Legal(
            List<Integer> bids,
            boolean canPass,
            List<String> trumpCards,
            List<String> cards,
            boolean canRevealTrump,
            boolean canShowPair) {

        public static final Legal NONE = new Legal(List.of(), false, List.of(), List.of(), false, false);

        @JsonIgnore
        public boolean isEmpty() {
            return bids.isEmpty() && !canPass && trumpCards.isEmpty() && cards.isEmpty()
                    && !canRevealTrump && !canShowPair;
        }
    }
}
