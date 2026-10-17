# Bot strategy

Bots (`Bot.java` / `bot.dart`) receive the same `PlayerView` a human gets. They never see hidden cards.
There are two levels: **Easy** plays random legal moves; **Normal** uses the heuristics below, which follow
standard advice from experienced 29 players.

## What makes 29 different

* Only 4 cards score, and the J and 9 hold 20 of the 28 points. Winning tricks matters much less than
  **capturing jacks and nines** and not giving away your own.
* The J is the top card of its suit, so a 9 is only safe once that suit's J is gone. Knowing which card is now
  the highest left in each suit (the "master") is most of the skill.
* Trump is hidden at first, so the bidder's side gets an information edge. The opponents usually want to
  force the reveal when it costs the bidder points.

## Bidding

The bot values its 4-card hand as `12 + card points + length of longest suit − (1 if no jack)`, capped at 28.
For example, J-x in one suit plus two blanks ≈ 17; J-9 in a suit plus an ace ≈ 20.
It bids the minimum legal amount while that is within its value, and it does not outbid its own partner
unless it is clearly stronger (+2). If everyone passes, the last player is forced to 16.

## Choosing trump

The bot scores each suit by `3 per card + its points + 2 for the jack`, picks the best one, and hides the
**lowest** card of that suit. That way its high trumps stay in hand, ready once trump is revealed.

## Card play

The bot tracks every card it has seen (own hand, completed tricks, current trick, hidden trump) to know which
cards are **masters**: no higher card of that suit is still unseen.

* **Leading:** if our side bid and trump is revealed, cash master trumps to pull the opponents' trumps.
  Otherwise lead a master that carries points. Otherwise lead low from a suit where we have no point
  cards an opponent could still capture.
* **Partner winning:** if the partner's card is safe (it is a master and nobody can trump it, or we play
  last), **feed points**: drop our best non-master point card. Otherwise play our cheapest card.
* **Opponent winning, can follow:** play last → win as cheaply as possible. Otherwise win only with a master;
  else throw the cheapest card (fewest points, lowest rank, never trump if avoidable).
* **Void:** feed points if the partner is safe. Otherwise ask for trump when the opponents are taking points
  (the bidder holds back if they hold no trumps). Once trump is revealed, ruff with the cheapest trump that
  wins (a master trump if the trick is worth points).
* Always shows a pair when allowed.

## Results (from the test suite)

* Normal vs Normal: contracts succeed ≈52% of the time at an average bid of ≈18, so bidding is balanced.
* Normal vs Easy: Normal takes ≈70% of all card points and wins ≈80% of deals.

## Next step: a "Hard" bot

Use **determinized Monte-Carlo search (PIMC)**: for each move, deal the unseen cards to the other seats many
times (consistent with what is known: voids shown, trump hidden or revealed), play each candidate move out
with the Normal bot, and pick the move with the best average points. With 32 cards this is cheap: about
200 samples per move runs in milliseconds on a phone or on the server.
