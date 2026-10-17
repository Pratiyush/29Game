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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(session: session)));
  }

  void _playOffline() {
    _open(TableSession.offline(name: _playerName, playerId: widget.prefs.playerId, level: _level));
  }

  void _online(Map<String, dynamic> intent) {
    _open(TableSession.online(name: _playerName, playerId: widget.prefs.playerId, intent: intent));
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
          decoration: const InputDecoration(hintText: 'Table code, e.g. K7QXP'),
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
      backgroundColor: AppColors.feltEdge,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Quick match'),
              subtitle: const Text('Play with anyone online. Bots fill empty seats.'),
              onTap: () {
                Navigator.pop(ctx);
                _online(const {'type': 'quickMatch'});
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create a table for friends'),
              subtitle: const Text('Share the code with your friends.'),
              onTap: () {
                Navigator.pop(ctx);
                _online(const {'type': 'createRoom'});
              },
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Join with a code'),
              onTap: () {
                Navigator.pop(ctx);
                _joinWithCode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openNearby() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyScreen(prefs: widget.prefs, name: _playerName, level: _level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _name,
                      maxLength: 16,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _playOffline,
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('Play with bots'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showOnlineMenu,
                      icon: const Icon(Icons.public),
                      label: const Text('Play online'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openNearby,
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Play nearby (Bluetooth)'),
                    ),
                    const SizedBox(height: 24),
                    Text('Bot skill', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<BotLevel>(
                      segments: const [
                        ButtonSegment(value: BotLevel.easy, label: Text('Easy')),
                        ButtonSegment(value: BotLevel.normal, label: Text('Normal')),
                      ],
                      selected: {_level},
                      onSelectionChanged: (s) => setState(() {
                        _level = s.first;
                        widget.prefs.botLevel = _level;
                      }),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppConfig.useMockBackend ? 'Online: mock server (in-app)' : 'Online: ${AppConfig.serverUrl}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (i, code) in const ['JS', 'JH', 'JC', 'JD'].indexed)
                Transform.rotate(
                  angle: (i - 1.5) * 0.22,
                  alignment: Alignment.bottomCenter,
                  child: CardSprite(code: code, width: 70),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '29',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900),
        ),
        Text('Twenty-nine', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
      ],
    );
  }
}
