import 'package:flutter/material.dart' hide Card;

import '../config.dart';
import '../engine/bot.dart';
import '../net/session.dart';
import '../prefs.dart';
import 'card_sprite.dart';
import 'nearby_screen.dart';
import 'session_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.prefs});

  final Prefs prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.prefs.name);
  late BotLevel _level = widget.prefs.botLevel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheCards(context);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _playerName {
    final n = _name.text.trim();
    widget.prefs.name = n;
    return n.isEmpty ? 'Player' : n;
  }

  void _open(TableSession session) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(session: session)));
  }

  void _playOffline() {
    _open(TableSession.offline(name: _playerName, playerId: widget.prefs.playerId, level: _level));
  }

  void _online(Map<String, dynamic> intent) {
    _open(TableSession.online(name: _playerName, playerId: widget.prefs.playerId, intent: intent));
  }

  void _openNearby() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyScreen(prefs: widget.prefs, name: _playerName, level: _level),
      ),
    );
  }

  Future<void> _joinWithCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 5,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: const InputDecoration(hintText: 'CODE'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Join')),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) _online({'type': 'joinRoom', 'code': code.trim()});
  }

  void _showOnlineMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.panelSolid,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: C.faint, borderRadius: BorderRadius.circular(2)),
              ),
              _ModeTile(
                icon: Icons.bolt_rounded,
                title: 'Quick match',
                subtitle: 'Play with anyone online',
                onTap: () {
                  Navigator.pop(ctx);
                  _online(const {'type': 'quickMatch'});
                },
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.group_add_rounded,
                title: 'Create a table',
                subtitle: 'Get a code to share with friends',
                onTap: () {
                  Navigator.pop(ctx);
                  _online(const {'type': 'createRoom'});
                },
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.login_rounded,
                title: 'Join with a code',
                subtitle: 'Enter a friend’s 5-letter code',
                onTap: () {
                  Navigator.pop(ctx);
                  _joinWithCode();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              // Landscape (the normal orientation) puts the wordmark beside the controls
              // so nothing needs scrolling.
              final wide = c.maxWidth > c.maxHeight;
              if (!wide) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const _Logo(), const SizedBox(height: 26), ..._controls(context, false)],
                      ),
                    ),
                  ),
                );
              }
              return Row(
                children: [
                  const Expanded(child: Center(child: _Logo(compact: true))),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 12, 28, 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _controls(context, true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(BuildContext context, bool wide) {
    final gap = wide ? 8.0 : 10.0;
    return [
      TextField(
        controller: _name,
        maxLength: 16,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          counterText: '',
          hintText: 'Your name',
          prefixIcon: Icon(Icons.person_outline, color: C.muted),
        ),
      ),
      SizedBox(height: wide ? 12 : 14),
      _ModeTile(
        icon: Icons.smart_toy_rounded,
        title: 'Play with bots',
        subtitle: 'Offline, starts instantly',
        primary: true,
        onTap: _playOffline,
      ),
      SizedBox(height: gap),
      _ModeTile(
        icon: Icons.public_rounded,
        title: 'Play online',
        subtitle: 'Quick match or a table for friends',
        onTap: _showOnlineMenu,
      ),
      SizedBox(height: gap),
      _ModeTile(
        icon: Icons.bluetooth_rounded,
        title: 'Play nearby',
        subtitle: 'Bluetooth, no internet needed',
        onTap: _openNearby,
      ),
      SizedBox(height: wide ? 14 : 22),
      _BotSkill(level: _level, onChanged: (l) => setState(() => widget.prefs.botLevel = _level = l)),
      const SizedBox(height: 12),
      Text(
        AppConfig.useMockBackend ? 'Online: in-app demo server' : 'Online: ${AppConfig.serverUrl}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: C.faint, fontSize: 11),
      ),
    ];
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.compact = false});

  final bool compact;

  static const _fan = ['JC', 'JD', 'JH', 'JS'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: compact ? 108 : 128,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (final (i, code) in _fan.indexed)
                Transform.translate(
                  offset: Offset((i - 1.5) * (compact ? 29 : 34), -(1.5 - (i - 1.5).abs()) * 6),
                  child: Transform.rotate(
                    angle: (i - 1.5) * 0.16,
                    alignment: Alignment.bottomCenter,
                    child: CardSprite(code: code, width: compact ? 64 : 76),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        GoldText('29', size: compact ? 62 : 76, letterSpacing: -2),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _Rule(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'TWENTY-NINE',
                style: TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 4),
              ),
            ),
            _Rule(),
          ],
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [C.gold.withValues(alpha: 0), C.gold.withValues(alpha: 0.6)]),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? C.ink : C.cream;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(colors: [C.goldBright, C.gold])
                : LinearGradient(colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.04)]),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: primary ? Colors.transparent : Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary ? C.ink.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary ? C.ink : C.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: primary ? C.ink.withValues(alpha: 0.7) : C.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primary ? C.ink.withValues(alpha: 0.6) : C.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotSkill extends StatelessWidget {
  const _BotSkill({required this.level, required this.onChanged});

  final BotLevel level;
  final ValueChanged<BotLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bot skill',
              style: TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          for (final l in BotLevel.values)
            GestureDetector(
              onTap: () => onChanged(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: level == l ? C.gold : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  l == BotLevel.easy ? 'Easy' : 'Normal',
                  style: TextStyle(color: level == l ? C.ink : C.muted, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
