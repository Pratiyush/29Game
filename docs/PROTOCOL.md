# Wire protocol (v1)

Every message is a JSON object with a `type`. The same messages are used:

* over WebSocket to the Quarkus backend at `ws://<host>:8080/ws`,
* in-process with the phone's `LocalServer` (offline and mock online),
* over Bluetooth between a guest and the host phone (one JSON object per Nearby bytes payload).

## Client → host

| type | fields | notes |
|------|--------|-------|
| `hello` | `playerId?`, `name` | **Must be first.** Reuse the saved `playerId` to get your seat back after a reconnect. |
| `quickMatch` | `name?` | Join or open a public table. It starts when full, or fills with bots after `quick-match-wait-ms`. |
| `createRoom` | `name?` | Private table; you are host. The reply `room.code` is the code to share. |
| `joinRoom` | `code`, `name?` | Case-insensitive. |
| `addBot` | | Host only, before start. |
| `startGame` | | Host only. Empty seats get bots. |
| `leaveRoom` | | Before the game the seat frees up; during it a bot takes over. Reply: `left`. |
| `bid` | `value` (int) | |
| `pass` | | |
| `chooseTrump` | `card` | Bidder hides this card; its suit is trump. |
| `play` | `card` | |
| `revealTrump` | | Only when you cannot follow suit. |
| `showPair` | | K+Q of trump, see RULES.md. |
| `ping` | | Reply: `pong`. |

Cards are `rank + suit`: ranks `J 9 A T K Q 8 7` (`T` = 10), suits `C D H S`. Examples: `JS`, `TH`, `7D`.

## Host → client

```jsonc
{"type":"welcome","playerId":"517bc98c-…","name":"Asha"}

{"type":"room","room":{
  "code":"48XYT","isPublic":true,"hostSeat":0,"status":"WAITING|PLAYING","yourSeat":0,
  "seats":[{"seat":0,"name":"Asha","bot":false,"connected":true}, null, null, null]}}

{"type":"state","view":{
  "seat":0, "phase":"BIDDING|CHOOSE_TRUMP|PLAYING|ROUND_OVER|MATCH_OVER",
  "round":1, "dealer":2, "turn":3,
  "hand":["7D","TH","KS","8S"],          // only your cards, sorted
  "hiddenTrump":null,                    // the face-down card, only for the bidder before reveal
  "trump":null,                          // suit code, once you may know it (bidder, or after reveal)
  "trumpRevealed":false,
  "bids":[{"seat":3,"value":16},{"seat":0,"value":null}],   // null = pass
  "highestBid":16, "bidder":3, "target":16,
  "trick":[{"seat":1,"card":"JH"}],      // current trick in play order
  "lastTrick":[], "lastTrickWinner":-1,
  "played":[],                           // cards from completed tricks (public)
  "teamPoints":[0,0],                    // this deal; index = seat % 2
  "matchScore":[0,0],
  "handCounts":[4,4,4,4],
  "pairShownBy":-1, "tricksPlayed":0,
  "lastRound":null,                      // {bidder,bid,target,bidderTeamPoints,success,delta}
  "matchWinner":-1,
  "legal":{"bids":[],"canPass":false,"trumpCards":[],"cards":[],"canRevealTrump":false,"canShowPair":false}
}}

{"type":"error","message":"Not your turn"}
{"type":"left"}
{"type":"pong"}
```

A `room` and a `state` are sent to every connected human after **every** change. Each one is a full
snapshot, so clients need no merge logic and a reconnect is just "send the latest snapshot". `legal` is only
filled in for the seat whose turn it is.

The Flutter connection layer also emits a local-only `{"type":"connection","status":"connected|reconnecting|closed"}`.
