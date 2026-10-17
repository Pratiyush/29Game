import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/bot.dart';
import '../net/nearby.dart';
import '../net/session.dart';
import '../prefs.dart';
import 'session_screen.dart';
import 'theme.dart';

/// Host a table, or find tables hosted by phones nearby (no internet needed).
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.prefs, required this.name, required this.level});

  final Prefs prefs;
  final String name;
  final BotLevel level;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  NearbyDiscovery? _discovery;
  StreamSubscription<List<NearbyTable>>? _sub;
  List<NearbyTable> _tables = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (nearbySupported) _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    final d = NearbyDiscovery();
    _discovery = d;
    _sub = d.tables.listen((t) => setState(() => _tables = t));
    try {
      await d.start(widget.name);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _stopDiscovery() async {
    await _sub?.cancel();
    await _discovery?.stop();
    _discovery = null;
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  Future<void> _open(TableSession session) async {
    await _stopDiscovery();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SessionScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play nearby'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: FeltBackground(
        child: SafeArea(
          child: !nearbySupported
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nearby play uses Google Nearby Connections and works on Android for now.\n'
                      'Use "Play online" or "Play with bots" on this device.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Host a table'),
                      onPressed: () => _open(
                        TableSession.nearbyHost(
                          name: widget.name,
                          playerId: widget.prefs.playerId,
                          level: widget.level,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your phone becomes the table. Friends join over Bluetooth; bots fill empty seats.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Text('Tables nearby', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 12),
                        if (_error == null)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    if (_error == null && _tables.isEmpty)
                      const Text(
                        'Searching… ask a friend to tap "Host a table".',
                        style: TextStyle(color: Colors.white60),
                      ),
                    for (final t in _tables)
                      Card(
                        color: AppColors.panel,
                        child: ListTile(
                          leading: const Icon(Icons.table_restaurant),
                          title: Text("${t.hostName}'s table"),
                          subtitle: Text('Code ${t.code}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            TableSession.nearbyGuest(name: widget.name, playerId: widget.prefs.playerId, table: t),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
