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

One set of design tokens in `app/lib/ui/theme.dart` drives every screen: emerald felt with a woven
texture, a bronze table rail, gold for anything you can act on, and a colour per team (teal = your side,
coral = theirs). Poppins (OFL) is bundled for type. The table, the lobby and the home screen all draw the
same felt and oval surface, so the game looks like one place rather than three screens.

The game runs in **landscape** (locked in `lib/main.dart`, the Android manifest and the iOS plist):
a card table is wider than it is tall, so the four seats, the trick and a fanned hand all fit without
scrolling. Every screen still lays out correctly in portrait, and the widget tests cover both.

A few deliberate details:

* **Seats sit on the rail** around an oval table, with your hand dealt over its lower edge and the partner opposite.
* **In landscape the whole auction is one row** (pass plus every legal bid), with no scrolling.
* **Whose turn it is** is a pulsing gold ring on that seat - no text to read.
* **Playable cards lift and glow**; cards you cannot legally play are dimmed, so the rules teach themselves.
* **Tricks animate**: each card deals in from its player's side, the winning card is ringed, then the trick
  sweeps to whoever took it.
* **The middle of the table is never empty**: it shows the live auction, or who won the last trick.
* **The scoreboard** shows match score per team plus a bar for the 28 card points in play, the contract, and
  the trump (face down until it is revealed, and only the bidder sees their own hidden card).

### Art

Card sprites are CC0 from [Kenney's Boardgame Pack](https://kenney.nl/assets/boardgame-pack), stored as
`app/assets/cards/<code>.png` (`JS.png` = jack of spades, `TH.png` = ten of hearts, `back.png` = card back).
To use generated art later, overwrite those files with images of the same aspect ratio (140×190). No code changes are needed, and a
missing image falls back to a drawn card. App icons are generated by `app/tool/make_icons.py`; credits are in
`app/assets/CREDITS.md`.

## Roadmap ideas

* Harder bots with Monte-Carlo sampling of hidden hands (see docs/BOTS.md).
* Accounts, ratings and friend lists on the backend (add Postgres/Redis outside the hot path).
* Horizontal scaling: route by room code (sticky sessions) or move room state to Redis.
* iOS nearby play via MultipeerConnectivity, chat/emotes, sounds and card animations.
