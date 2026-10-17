# Rules implemented

29 has many house variants. This is the one the engine implements (`Game.java` / `game.dart`).
Constants are at the top of both files.

## Players and cards

* 4 players in 2 fixed partnerships: seats 0 & 2 against seats 1 & 3 (partners sit opposite).
* 32 cards: J, 9, A, 10, K, Q, 8, 7 in each suit, **ranked in that order** (jack highest).
* Card points: **J = 3, 9 = 2, A = 1, 10 = 1**, others 0. Total = **28** per deal.
* Play passes to the right (counter-clockwise), as is traditional.

## Deal and bidding

1. The dealer rotates every deal. Each player gets 4 cards.
2. Bidding starts left of the dealer. On your turn you raise the bid (minimum **16**, maximum **28**) or pass.
   A player who passes is out of the auction.
3. If the first three players pass, the last player must bid 16.
4. Bidding ends when only the highest bidder is left, or someone bids 28.

## Trump

* The bid winner chooses trump by placing one of their 4 cards **face down**. Its suit is trump.
  Nobody else knows the trump yet.
* Everyone then gets 4 more cards (8 each; the bidder holds 7 plus the face-down card).
* The player left of the dealer leads the first trick.

## Play

* You must follow the led suit if you can.
* If you cannot follow suit you may **ask for trump**. It is revealed to everyone and the face-down card
  goes back to the bidder's hand. After asking, you must play a trump if you hold one.
* Before trump is revealed, trump-suit cards do not count as trumps. A trick is won by the highest trump
  in it (if trump has been revealed by the end of the trick), otherwise by the highest card of the led suit.
* If the bidder's only card left is the face-down trump, it is revealed automatically.

## Pair (marriage)

After trump is revealed, a player holding **K and Q of trump** may show the pair on their turn, once their
team has won a trick since the reveal. Only one pair per deal:

* Shown by the bidding team: the target drops by 4 (never below 16).
* Shown by the opponents: the target rises by 4 (never above 28).

## Scoring

* After 8 tricks: if the bidding team took at least the target in card points, it scores **+1** game point;
  otherwise **−1**.
* The match ends when a team reaches **+6** (they win) or **−6** (they lose).

## Not implemented (yet)

Redeal on special hands, a "double/redouble" call, single-hand (bidder plays alone), counting the last trick
as a point, and the "seventh card" trump variant.
