import 'package:flutter/material.dart' hide Card;

import '../config.dart';
import '../net/session.dart';
import '../prefs.dart';
import 'card_sprite.dart';
import 'nearby_screen.dart';
import 'profile_screens.dart';
import 'session_screen.dart';
import 'theme.dart';

/// Home: profile header, one big Play button, and the other ways to play.
/// Modelled on what the most-installed 29 apps open with.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.prefs});

  final Prefs prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Prefs get prefs => widget.prefs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheCards(context);
  }

  String get _playerName => prefs.name.isEmpty ? 'Player' : prefs.name;

  void _open(TableSession session) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(session: session)));
  }

  void _playOffline() {
    _open(
      TableSession.offline(
        name: _playerName,
        playerId: prefs.playerId,
        level: prefs.botLevel,
        avatar: prefs.avatar,
        botDelay: prefs.speed.botDelay,
      ),
    );
  }

  void _online(Map<String, dynamic> intent) {
    _open(TableSession.online(name: _playerName, playerId: prefs.playerId, intent: intent, avatar: prefs.avatar));
  }

  void _openNearby() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyScreen(prefs: prefs, name: _playerName, level: prefs.botLevel),
      ),
    );
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

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
          decoration: const InputDecoration(hintText: 'CODE', counterText: ''),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.panelSolid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
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
    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
      child: Row(
        children: [
          ProfileHeader(prefs: prefs),
          const Spacer(),
          _IconAction(icon: Icons.menu_book_rounded, label: 'Rules', onTap: () => _push(const RulesScreen())),
          _IconAction(
            icon: Icons.leaderboard_rounded,
            label: 'Stats',
            onTap: () => _push(StatsScreen(prefs: prefs)),
          ),
          _IconAction(icon: Icons.settings_rounded, label: 'Settings', onTap: () => showSettings(context, prefs)),
        ],
      ),
    );

    final play = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlayButton(onTap: _playOffline),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModeTile(
                icon: Icons.public_rounded,
                title: 'Online',
                subtitle: 'Quick match or friends',
                onTap: _showOnlineMenu,
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeTile(
                icon: Icons.bluetooth_rounded,
                title: 'Nearby',
                subtitle: 'Bluetooth, no internet',
                onTap: _openNearby,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppConfig.useMockBackend ? 'Online: in-app demo server' : 'Online: ${AppConfig.serverUrl}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.faint, fontSize: 10.5),
        ),
      ],
    );

    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > c.maxHeight;
              return Column(
                children: [
                  topBar,
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(child: Center(child: _Logo(compact: true))),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(8, 8, 28, 12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 400),
                                      child: play,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [const _Logo(), const SizedBox(height: 28), play],
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
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: C.ink.withValues(alpha: 0.55),
        shape: CircleBorder(side: BorderSide(color: C.gold.withValues(alpha: 0.45))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 21, color: C.goldBright),
          ),
        ),
      ),
    ),
  );
}

/// The one obvious thing to do: start a game against bots right now.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Decorate outside the ink layer so the shadow and the ripple share the rounded shape.
    final radius = BorderRadius.circular(AppRadius.lg);
    return Container(
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.goldBright, C.gold, C.goldDeep],
        ),
        borderRadius: radius,
        boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: C.ink, size: 38),
              SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAY NOW',
                    style: TextStyle(
                      color: C.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: 1,
                    ),
                  ),
                  Text('vs bots · works offline', style: TextStyle(color: Color(0xB3071A12), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.compact = false});

  final bool compact;

  static const _fan = ['JC', 'JD', 'JH', 'JS'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 116 : 132,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (final (i, code) in _fan.indexed)
                Transform.translate(
                  offset: Offset((i - 1.5) * (compact ? 30 : 36), -(1.5 - (i - 1.5).abs()) * 7),
                  child: Transform.rotate(
                    angle: (i - 1.5) * 0.17,
                    alignment: Alignment.bottomCenter,
                    child: CardSprite(code: code, width: compact ? 70 : 80, elevation: 1.5),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 16),
        GoldText('29', size: compact ? 60 : 76, letterSpacing: -2),
        const SizedBox(height: 2),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: C.gold.withValues(alpha: 0.22)),
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 11 : 13),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: C.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: C.gold, size: compact ? 20 : 22),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: C.cream, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.muted, fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (!compact) const Icon(Icons.chevron_right_rounded, color: C.faint),
            ],
          ),
        ),
      ),
    );
  }
}
