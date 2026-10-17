# What the leading 29 apps do (October 2026)

I studied the Google Play store listings and screenshots of the ten most-visible 29 apps, to see what
players already expect, then built the parts that make the game feel finished.

| App | Installs | Rating | What stands out |
|-----|----------|--------|-----------------|
| [Card Game 29](https://play.google.com/store/apps/details?id=com.zlevelapps.cardgame29) (Z Level) | 10M+ | 4.2 | Plain but clear table; how-to-play; "You have won the set!" celebration; single hand, double/redouble |
| [Cards Game 29 Offline](https://play.google.com/store/apps/details?id=com.ulkagames.twentynine) (29 Gold) | 5M+ | 3.6 | Rich purple/gold art, character avatars, private tables, game modes, shop |
| [29 King](https://play.google.com/store/apps/details?id=com.vipgames.twentynine) | 1M+ | 4.3 | Polished: big portrait avatars in gold rings, "Your team points 0/22 vs Opponents 0/10", trump and Last Hand slots on the table, profile with level bar, avatar/frame store |
| [29 Card Game – Expert AI](https://play.google.com/store/apps/details?id=com.neuralplay.android.twentynine) (NeuralPlay) | 1M+ | 4.0 | Functional, data-dense: need/taken table, play review, strong AI |
| [29 Card Master – INDIA](https://play.google.com/store/apps/details?id=com.minigamelab.twentynine) | 500K+ | 4.2 | Marriage banner with confetti, emoji + quick-chat phrases, bid grid, "Last hand" |
| [Card Game 29 – Multiplayer Pro](https://play.google.com/store/apps/details?id=com.bombayplay.TwentyNine) (Bombay Play) | 500K+ | 4.0 | Landscape table, **point badges above each card in your hand**, reactions, coins |
| [29 Master Card Game Offline](https://play.google.com/store/apps/details?id=com.livegames.twentynine) | 500K+ | 4.2 | Classic layout |
| [29 card game online play](https://play.google.com/store/apps/details?id=com.dynamitegamesltd.twentynineonline) | 500K+ | 3.9 | Online-first |
| [29 Card Game Legends](https://play.google.com/store/apps/details?id=com.SoulSparkGames.TwentyNineGoldLegends) | 5K+ | 4.8 | Suit picker for trump, choose-your-avatar, detailed stats ("track every win"), "no punishment cards" |
| [29 card game: LIVE Voice Chat](https://play.google.com/store/apps/details?id=com.play29.twentyNine) | 1K+ | 4.9 | Modern dark UI: home with "three ways to play", streaks, missions, resume-table card |

On the App Store the same names lead (29 Card Master, Play 29 LIVE, 29 Card Game – Twenty Nine), with the same
screenshots.

## What they all share, and what we now do

| Players expect | Ours, before | Ours, now |
|----------------|-------------|-----------|
| Readable cards with real court designs | Placeholder cards with a blank crown | Own generated deck: big indexes, pip layouts, framed courts, gold star on jacks |
| Portraits in rings, name plates | Robot icon or an initial | 16 CC0 portraits, pick yours; gold pulsing ring on turn; BOT tag |
| Team points against what is needed | `points / 28` | Bidders `x / target`, defenders `x / (29 − target)` |
| Trump and Last Hand on the table | Trump in the header only, no review | Trump badge + **Last hand** dialog |
| Choose trump by suit | Tap a card | Suit picker (tapping a card still works) |
| Card point badges (Bombay Play) | — | Gold badges on J 9 A 10 in your hand (switchable) |
| Reactions / quick chat | — | 8 emoji + 4 phrases, relayed online and over Bluetooth; bots react at deal end |
| Celebrations | Plain summary | Banners for trump reveal and pair, confetti on wins |
| Sound and vibration | Silent | CC0 card-table sounds + haptics, switchable |
| Profile, level, stats | Name field | Profile header with XP level, lifetime stats screen |
| How to play | Only in docs | In-app rules with the point cards shown |
| Settings | Bot skill only | Sound, vibration, card points, bot skill, game speed, card back |

## Deliberately not copied

* **Coins, shops and pay-to-win.** Several apps gate tables behind coins; their reviews complain about it.
  Legends and Play 29 LIVE market "no punishment" and "no pay-to-win" for exactly that reason.
* **Free-text chat.** Fixed reactions give the social feel without anything to moderate.
* **Fake "real players".** Bots are labelled, online and off.

## Still missing compared with the leaders

* Accounts, leaderboards and friend lists (needs a database behind the backend).
* Daily streaks and missions (Play 29 LIVE), cosmetic frames and table themes.
* Voice chat in private tables.
* Rule variants many apps offer: double/redouble, single hand, 7th-card trump.
