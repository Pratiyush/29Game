/// Profile header, stats, rules and settings: the meta screens every leading 29 app has.
library;

import 'package:flutter/material.dart' hide Card;

import '../engine/bot.dart';
import '../prefs.dart';
import 'avatar.dart';
import 'card_sprite.dart';
import 'theme.dart';

/// Portrait, name and level bar. Tap the portrait to change it, the name to rename.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.prefs});

  final Prefs prefs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final name = prefs.name.isEmpty ? 'Player' : prefs.name;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final a = await pickAvatar(context, prefs.avatar);
                if (a != null) prefs.avatar = a;
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarPortrait(avatar: prefs.avatar, name: name, size: 52),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [C.goldBright, C.gold]),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: C.ink, width: 1.5),
                      ),
                      child: Text(
                        '${prefs.level}',
                        style: const TextStyle(color: C.ink, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => editName(context, prefs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded, size: 14, color: C.faint),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 150,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: prefs.levelProgress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            color: C.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Lv ${prefs.level}', style: const TextStyle(fontSize: 10.5, color: C.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> editName(BuildContext context, Prefs prefs) async {
  final controller = TextEditingController(text: prefs.name);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 16,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(counterText: '', hintText: 'Shown at the table'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
      ],
    ),
  );
  controller.dispose();
  if (name != null) prefs.name = name.trim();
}

/// A screen with the felt background, a back button and a title.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FeltBackground(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ stats

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.prefs});

  final Prefs prefs;

  @override
  Widget build(BuildContext context) {
    final p = prefs;
    String pct(int a, int b) => b == 0 ? '—' : '${(100 * a / b).round()}%';
    final tiles = [
      ('Matches won', '${p.matchesWon}', 'of ${p.matchesPlayed} played', Icons.emoji_events_rounded),
      ('Match win rate', pct(p.matchesWon, p.matchesPlayed), 'first to +6', Icons.percent_rounded),
      ('Deals won', '${p.dealsWon}', 'of ${p.dealsPlayed} played', Icons.style_rounded),
      ('Deal win rate', pct(p.dealsWon, p.dealsPlayed), 'bid or defended', Icons.trending_up_rounded),
      ('Contracts made', '${p.contractsMade}', 'of ${p.bidsWon} you called', Icons.gavel_rounded),
      ('Highest bid', p.highestBid == 0 ? '—' : '${p.highestBid}', 'that you won', Icons.north_rounded),
      ('Current streak', '${p.streak}', 'deals in a row', Icons.local_fire_department_rounded),
      ('Best streak', '${p.bestStreak}', 'deals in a row', Icons.workspace_premium_rounded),
    ];
    return _Sheet(
      title: 'Your stats',
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : 2;
          return GridView.count(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              for (final (label, value, sub, icon) in tiles)
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(icon, color: C.gold, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(sub, style: const TextStyle(fontSize: 10.5, color: C.faint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ rules

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _sections = [
    (
      'The goal',
      'Four players in two teams; your partner sits opposite. Each deal, one team promises to take a number '
          'of card points (the bid). Make it and your team scores +1; fall short and it scores −1. '
          'First team to +6 wins the match; a team that sinks to −6 loses it.',
    ),
    (
      'Bidding',
      'Everyone gets 4 cards. Starting left of the dealer, bid 16 to 28 or pass. Once you pass you are out. '
          'The highest bidder wins the contract. If the first three pass, the last player must bid 16.',
    ),
    (
      'Trump',
      'The bid winner picks trump and places one card of that suit face down. Nobody else knows the suit. '
          'Everyone then gets 4 more cards.',
    ),
    (
      'Playing',
      'Follow the suit that was led if you can. If you cannot, you may ask for trump: it is turned face up and, '
          'if you hold a trump, you must play one. Highest trump wins the trick, otherwise the highest card of the '
          'suit led. Trumps only count once revealed.',
    ),
    (
      'Pair (marriage)',
      'Hold the king and queen of trump after it is revealed, and once your team has won a trick, show the pair: '
          'the target drops by 4 if your team bid, or rises by 4 if you are defending.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'How to play 29',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Panel(
            border: C.gold.withValues(alpha: 0.3),
            child: Column(
              children: [
                const Text(
                  'CARDS RANK J · 9 · A · 10 · K · Q · 8 · 7',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: C.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (final (code, pts) in const [('JS', 3), ('9H', 2), ('AD', 1), ('TC', 1)])
                      Column(
                        children: [
                          CardSprite(code: code, width: 54),
                          const SizedBox(height: 6),
                          Text(
                            '$pts ${pts == 1 ? 'point' : 'points'}',
                            style: const TextStyle(color: C.goldBright, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Every other card is worth 0. There are 28 points in each deal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final (title, body) in _sections) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.goldBright),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(fontSize: 13, height: 1.5, color: C.cream)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ settings

Future<void> showSettings(BuildContext context, Prefs prefs) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.panelSolid,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _Switch('Sound effects', prefs.sound, (v) => prefs.sound = v),
                _Switch('Vibration', prefs.haptics, (v) => prefs.haptics = v),
                _Switch('Show card points in hand', prefs.showPoints, (v) => prefs.showPoints = v),
                const SizedBox(height: 10),
                _Segmented<BotLevel>(
                  label: 'Bot skill',
                  value: prefs.botLevel,
                  options: const {BotLevel.easy: 'Easy', BotLevel.normal: 'Normal'},
                  onChanged: (v) => prefs.botLevel = v,
                ),
                const SizedBox(height: 10),
                _Segmented<GameSpeed>(
                  label: 'Game speed',
                  value: prefs.speed,
                  options: const {GameSpeed.relaxed: 'Relaxed', GameSpeed.normal: 'Normal', GameSpeed.fast: 'Fast'},
                  onChanged: (v) => prefs.speed = v,
                ),
                const SizedBox(height: 14),
                const Text('Card back', style: TextStyle(color: C.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final back in const ['back', 'back_red'])
                      GestureDetector(
                        onTap: () => prefs.cardBack = back,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: prefs.cardBack == back ? C.goldBright : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Image.asset('assets/cards/$back.png', width: 56),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 14)),
    value: value,
    activeThumbColor: C.gold,
    onChanged: onChanged,
  );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: C.muted, fontSize: 13)),
      ),
      for (final e in options.entries)
        GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: value == e.key ? C.gold : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              e.value,
              style: TextStyle(color: value == e.key ? C.ink : C.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
    ],
  );
}
