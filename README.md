# 29 (Twenty-nine)

The Indian trick-taking card game 29 for phones. You can play three ways:

| Mode | How it connects | Who plays |
|------|-----------------|-----------|
| **Play with bots** | No network. Everything runs on the phone. | You + 3 bots |
| **Play online** | WebSocket to the Quarkus backend (or the in-app **mock** backend) | Quick match with anyone, or a private table for friends (share a 5-letter code). Bots fill empty seats. |
| **Play nearby** | Bluetooth / Wi-Fi Direct (Google Nearby Connections, Android). No internet needed. | One phone hosts, friends nearby join, bots fill empty seats. |

```
29Game/
├── app/        Flutter app (Android, iOS, web)
├── backend/    Quarkus server: matchmaking, rooms, authoritative rules, bots
└── docs/       RULES.md · PROTOCOL.md · BOTS.md
```

## Architecture

```
            ┌──────────────── Flutter app ────────────────┐
            │  UI (home · lobby · table)                  │
            │        │ listens to                         │
            │  TableSession ── GameConnection (JSON msgs) │
            │                    │                        │
            │   ┌────────────────┼──────────────────┐     │
            │   │                │                  │     │
            │ LocalServer    WsGameConnection   NearbyGuestConnection
            │ (in-process)        │                  │     │
            └───┼─────────────────┼──────────────────┼─────┘
                │                 │ WebSocket        │ Bluetooth
   offline / mock / BT host       ▼                  ▼
                           Quarkus backend      host phone's LocalServer
```

* **The same JSON protocol everywhere** ([docs/PROTOCOL.md](docs/PROTOCOL.md)). The phone runs `LocalServer`,
  a Dart twin of the Quarkus server. It serves offline games, the mock online backend and Bluetooth hosting,
  so all four paths behave the same.
* **The host is authoritative.** Clients send intents (`bid`, `play`, …). The host checks them against the
  rules and sends each seat its own `PlayerView`: only that seat's cards plus its legal moves. A client never
  sees other hands, so it cannot cheat, and the UI never has to work out the rules itself.
* **Bots use the same `PlayerView` as people**, so they play fair. Strategy: [docs/BOTS.md](docs/BOTS.md).
* **Rules engine in two languages**: `backend/.../engine/Game.java` and `app/lib/engine/game.dart` are line-for-line
  ports and must change together. Both run the same invariant tests (thousands of bot games, 28 points per
  round, no illegal moves).

### Why the backend is fast

* Quarkus 3 with `websockets-next` on Vert.x: non-blocking I/O, starts in about 1 s on the JVM (milliseconds as a native image).
* All state is in memory. One lock per room, so rooms never contend with each other.
* Each move costs one small JSON snapshot per seat (~1.5 KB), with no database on the hot path.
* Reconnects: the client re-sends `hello` with its saved `playerId` and gets its seat back. A bot plays for it while it is away.

## Running it

### Backend (Java 21 + Maven)

```bash
cd backend
mvn quarkus:dev                 # live reload on :8080, WebSocket at ws://localhost:8080/ws
mvn test                        # engine + WebSocket integration tests
mvn package && java -jar target/quarkus-app/quarkus-run.jar
docker build -t game29-backend . && docker run -p 8080:8080 game29-backend
```

Health: `GET /q/health`, status: `GET /api/status`. Pacing is set in `application.properties`
(`game29.bot-delay-ms`, `game29.round-pause-ms`, `game29.quick-match-wait-ms`).

### App (Flutter 3.47+)

```bash
cd app
flutter pub get
flutter run                     # online mode uses the in-app MOCK backend (default)
flutter run --dart-define=BACKEND=server --dart-define=SERVER_URL=ws://10.0.2.2:8080/ws
                                # real backend (10.0.2.2 = your computer from the Android emulator)
flutter test                    # engine, local server, mock backend and widget tests
flutter run -d chrome           # web build: bots + online (nearby is Android-only)
```

**Mock backend:** with `BACKEND=mock` (the default), "Play online" runs `LocalServer` in mock mode. Quick match
"finds" a couple of online players (bots with player-like names), and joining any 5-letter code opens a friend's
table. That lets you build the app without running the server. Switching to the real server is one flag.

**Nearby / Bluetooth** uses [`nearby_connections`](https://pub.dev/packages/nearby_connections) (Android only).
It needs a real device: emulators have no Bluetooth. iOS shows a message for now. Apple's equivalent
(MultipeerConnectivity) can be added as another `GameConnection` without touching the game code.

## Look and feel

The design was benchmarked against the store listings of the ten most-installed 29 apps (Z Level's
*Card Game 29*, *29 Gold*, *29 King*, *29 Card Master*, Bombay Play, NeuralPlay, *Play 29 LIVE* and others);
see [docs/COMPETITORS.md](docs/COMPETITORS.md). The game runs in **landscape**, like a real card table.

* **Cards** from our own generator: big corner indexes you can read in a tight fan, classic pip layouts,
  framed court cards, and a gold star on the jacks (the top card in 29). Each scoring card in your hand
  carries a small badge with its points (J 3, 9 2, A 1, 10 1).
* **Portraits** on every seat (16 CC0 avatars; you pick yours), in a ring that is gold and pulsing when it is
  that player's turn. Opponents' remaining cards fan out behind them; bots wear a BOT tag.
* **Scoreboard** shows each team's points against what *it* needs: the bidders race to the target, the
  defenders to `29 − target`. Plus the contract, trick count and the trump (face down until revealed).
* **Choose trump** with a suit picker, **Last hand** to review the previous trick, **reactions** (8 emoji and
  4 fixed phrases, relayed to the table online and over Bluetooth; no free text to moderate).
* **Moments**: banners when trump is revealed or a pair is shown, confetti when your side wins a deal (more
  for a match), and card-table sounds with haptics, all switchable in settings.
* **Home** opens on your profile (portrait, name, level from XP), one big **PLAY NOW**, and Online / Nearby.
  Rules (with the point values on real cards), lifetime **stats** (match and deal win rates, contracts made,
  highest bid, streaks) and **settings** (sound, vibration, card points, bot skill, game speed, card back).

### Art and sound

All bundled art and audio is ours or CC0; see `app/assets/CREDITS.md`. Card faces come from
`app/tool/make_cards.py` and icons from `app/tool/make_icons.py`. To switch to generated art later,
overwrite `app/assets/cards/<code>.png` (and `avatars/aNN.png`) with same-named files.

## Roadmap ideas

* Harder bots with Monte-Carlo sampling of hidden hands (see docs/BOTS.md).
* Accounts, ratings and friend lists on the backend (add Postgres/Redis outside the hot path).
* Horizontal scaling: route by room code (sticky sessions) or move room state to Redis.
* iOS nearby play via MultipeerConnectivity, chat/emotes, sounds and card animations.
