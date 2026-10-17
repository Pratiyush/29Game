# 29 - Flutter app

See the [project README](../README.md) for modes, architecture and run commands.

```
lib/
  engine/   rules (game.dart), bots (bot.dart), cards, PlayerView model - mirrors backend/…/engine
  net/      GameConnection + implementations: LocalServer (offline / mock / BT host),
            WsGameConnection (Quarkus), Nearby (Bluetooth), TableSession (client state)
  ui/       home, nearby, lobby and table screens; card_sprite.dart renders assets/cards/*.png
```
