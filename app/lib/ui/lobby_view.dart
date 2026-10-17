import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/connection.dart';
import '../net/session.dart';
import 'theme.dart';

/// Waiting room: who is seated, the table code to share, and host controls.
class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.session, required this.onLeave});

  final TableSession session;
  final VoidCallback onLeave;

  String get _title => switch (session.kind) {
    SessionKind.offline => 'Dealing…',
    SessionKind.online => session.room?.isPublic ?? true ? 'Finding players…' : 'Your table',
    SessionKind.nearbyHost => 'Hosting nearby table',
    SessionKind.nearbyGuest => 'Joining nearby table',
  };

  @override
  Widget build(BuildContext context) {
    final room = session.room;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: onLeave, icon: const Icon(Icons.arrow_back)),
            Expanded(child: Text(_title, style: text.titleLarge)),
            _ConnectionDot(status: session.connectionStatus),
            const SizedBox(width: 16),
          ],
        ),
        Expanded(
          child: room == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (!room.isPublic) _CodeCard(code: room.code, nearby: session.kind == SessionKind.nearbyHost),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 4; i++) _SeatTile(seat: i, info: room.seats[i], room: room),
                    const SizedBox(height: 24),
                    if (room.amHost && !room.isPublic) ...[
                      OutlinedButton.icon(
                        onPressed: room.seats.contains(null) ? session.addBot : null,
                        icon: const Icon(Icons.smart_toy),
                        label: const Text('Add a bot'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: session.startGame,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start (bots fill empty seats)'),
                      ),
                    ] else if (room.isPublic)
                      const _Hint('The game starts when the table is full, or with bots after a few seconds.')
                    else
                      const _Hint('Waiting for the host to start…'),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.nearby});

  final String code;
  final bool nearby;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(
            nearby ? 'Friends nearby can now find your table' : 'Share this code with friends',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: AppColors.gold,
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.info, required this.room});

  final int seat;
  final SeatInfo? info;
  final RoomInfo room;

  @override
  Widget build(BuildContext context) {
    final color = teamColor(seat, room.yourSeat);
    final team = seat % 2 == room.yourSeat % 2 ? 'Your team' : 'Opponents';
    final s = info;
    return Card(
      color: AppColors.panel,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: AppColors.ink,
          child: s == null
              ? const Icon(Icons.hourglass_empty)
              : s.bot
              ? const Icon(Icons.smart_toy)
              : Text(s.name.characters.first.toUpperCase()),
        ),
        title: Text(s == null ? 'Waiting…' : (seat == room.yourSeat ? '${s.name} (you)' : s.name)),
        subtitle: Text(team + (seat == room.hostSeat ? ' · host' : '')),
        trailing: s != null && !s.connected ? const Icon(Icons.wifi_off, color: Colors.white38) : null,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(color: Colors.white60),
  );
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'connected' => Colors.greenAccent,
      'reconnecting' || 'connecting' => Colors.amber,
      _ => Colors.redAccent,
    };
    return Tooltip(
      message: status,
      child: Icon(Icons.circle, size: 12, color: color),
    );
  }
}
