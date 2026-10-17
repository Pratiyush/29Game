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
      body: FeltBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const Expanded(
                    child: Text('Play nearby', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Expanded(child: nearbySupported ? _body(context) : const _Unsupported()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Landscape: hosting on one side, the tables found on the other.
        if (c.maxWidth > c.maxHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 10, 20), child: _hostCard()),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(10, 8, 20, 20), children: _found()),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [_hostCard(), const SizedBox(height: 26), ..._found()],
        );
      },
    );
  }

  Widget _hostCard() {
    return Column(
      children: [
        Panel(
          padding: const EdgeInsets.all(18),
          border: C.gold.withValues(alpha: 0.25),
          child: Column(
            children: [
              const Icon(Icons.wifi_tethering_rounded, color: C.gold, size: 32),
              const SizedBox(height: 10),
              const Text('Host the table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Your phone deals and keeps score. Friends nearby join over Bluetooth, and bots take any empty seat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _open(
                    TableSession.nearbyHost(name: widget.name, playerId: widget.prefs.playerId, level: widget.level),
                  ),
                  child: const Text('Host a table'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _found() {
    return [
      Row(
        children: [
          const Text('TABLES NEARBY', style: TextStyle(fontSize: 10, letterSpacing: 2, color: C.muted)),
          const SizedBox(width: 10),
          if (_error == null)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: C.gold)),
        ],
      ),
      const SizedBox(height: 10),
      if (_error != null)
        Panel(
          border: C.bad.withValues(alpha: 0.4),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: C.bad, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_error!, style: const TextStyle(color: C.cream, fontSize: 12.5, height: 1.4)),
              ),
            ],
          ),
        )
      else if (_tables.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Searching… ask a friend to tap "Host a table".',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.faint, fontSize: 12.5),
          ),
        ),
      for (final t in _tables)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () =>
                  _open(TableSession.nearbyGuest(name: widget.name, playerId: widget.prefs.playerId, table: t)),
              child: Panel(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_bar_rounded, color: C.gold, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.hostName}’s table',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          Text('Code ${t.code}', style: const TextStyle(color: C.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: C.faint),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(28),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_disabled_rounded, color: C.faint, size: 40),
          SizedBox(height: 14),
          Text(
            'Nearby play uses Google Nearby Connections, which is Android only for now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted, fontSize: 13, height: 1.5),
          ),
          SizedBox(height: 8),
          Text(
            'On this device, try "Play online" or "Play with bots".',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.faint, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
