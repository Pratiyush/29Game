import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/connection.dart';
import '../net/session.dart';
import 'avatar.dart';
import 'theme.dart';

/// Waiting room: the table with seats filling up, the code to share, and host controls.
class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.session, required this.onLeave});

  final TableSession session;
  final VoidCallback onLeave;

  String get _title => switch (session.kind) {
    SessionKind.offline => 'Dealing…',
    SessionKind.online => (session.room?.isPublic ?? true) ? 'Finding players' : 'Your table',
    SessionKind.nearbyHost => 'Hosting nearby',
    SessionKind.nearbyGuest => 'Joining table',
  };

  @override
  Widget build(BuildContext context) {
    final room = session.room;
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: onLeave, icon: const Icon(Icons.arrow_back_rounded), color: C.cream),
            Expanded(
              child: Text(_title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            _ConnectionDot(status: session.connectionStatus),
            const SizedBox(width: 18),
          ],
        ),
        Expanded(
          child: room == null
              ? const Center(child: CircularProgressIndicator(color: C.gold))
              : LayoutBuilder(
                  builder: (context, c) {
                    // Landscape: the table sits beside the code and the host controls.
                    final wide = c.maxWidth > c.maxHeight;
                    final side = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!room.isPublic) ...[
                          _CodeCard(code: room.code, nearby: session.kind == SessionKind.nearbyHost),
                          const SizedBox(height: 18),
                        ],
                        ..._controls(room),
                      ],
                    );
                    if (wide) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: side),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Center(child: _LobbyTable(room: room)),
                            ),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight - 24, maxWidth: 420),
                        child: Center(
                          child: Column(
                            children: [
                              if (!room.isPublic) ...[
                                _CodeCard(code: room.code, nearby: session.kind == SessionKind.nearbyHost),
                                const SizedBox(height: 18),
                              ],
                              _LobbyTable(room: room),
                              const SizedBox(height: 20),
                              ..._controls(room),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Widget> _controls(RoomInfo room) {
    if (room.amHost && !room.isPublic) {
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: room.seats.contains(null) ? session.addBot : null,
                icon: const Icon(Icons.smart_toy_rounded, size: 18),
                label: const Text('Add bot'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: session.startGame,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _Hint('Empty seats are filled with bots when you start.'),
      ];
    }
    return [
      _Hint(
        room.isPublic
            ? 'Starts when the table is full, or with bots after a few seconds.'
            : 'Waiting for the host to start\u2026',
      ),
    ];
  }
}

/// The four seats arranged as they will be at the table, so joining feels like sitting down.
class _LobbyTable extends StatelessWidget {
  const _LobbyTable({required this.room});

  final RoomInfo room;

  @override
  Widget build(BuildContext context) {
    // Seats relative to me: me at the bottom, partner opposite, opponents left and right.
    int seatAt(int relative) => (room.yourSeat + relative) % 4;
    return SizedBox(
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Padding(padding: EdgeInsets.all(14), child: TableSurface()),
          Opacity(
            opacity: 0.1,
            child: Text(
              '29',
              style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: C.goldBright, letterSpacing: -2),
            ),
          ),
          Align(
            alignment: const Alignment(0, -1),
            child: _LobbySeat(room: room, seat: seatAt(2)),
          ),
          Align(
            alignment: const Alignment(-1, 0),
            child: _LobbySeat(room: room, seat: seatAt(3)),
          ),
          Align(
            alignment: const Alignment(1, 0),
            child: _LobbySeat(room: room, seat: seatAt(1)),
          ),
          Align(
            alignment: const Alignment(0, 1),
            child: _LobbySeat(room: room, seat: room.yourSeat),
          ),
        ],
      ),
    );
  }
}

class _LobbySeat extends StatelessWidget {
  const _LobbySeat({required this.room, required this.seat});

  final RoomInfo room;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final info = room.seats[seat];
    final me = seat == room.yourSeat;
    final color = teamColor(seat, room.yourSeat);
    final sameTeam = seat % 2 == room.yourSeat % 2;
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info == null)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.ink.withValues(alpha: 0.85),
                border: Border.all(color: C.faint.withValues(alpha: 0.45)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_add_alt_1_rounded, color: C.faint, size: 20),
            )
          else
            AvatarPortrait(avatar: info.avatar, name: info.name, size: 56, ring: color),
          const SizedBox(height: 6),
          Text(
            info == null ? 'Open seat' : (me ? 'You' : info.name.replaceAll(' (bot)', '')),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: info == null ? C.faint : C.cream),
          ),
          Text(
            info != null && seat == room.hostSeat
                ? 'host'
                : '${info?.bot ?? false ? 'bot · ' : ''}${sameTeam ? 'your team' : 'opponent'}',
            style: const TextStyle(fontSize: 10, color: C.faint),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.nearby});

  final String code;
  final bool nearby;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      border: C.gold.withValues(alpha: 0.28),
      child: Column(
        children: [
          Text(
            nearby ? 'FRIENDS NEARBY CAN JOIN THIS TABLE' : 'SHARE THIS CODE',
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 34),
              GoldText(code, size: 40, letterSpacing: 7),
              SizedBox(
                width: 34,
                child: IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: C.muted),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
                ),
              ),
            ],
          ),
        ],
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
    style: const TextStyle(color: C.faint, fontSize: 12, height: 1.4),
  );
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'connected' => (C.good, 'Connected'),
      'reconnecting' || 'connecting' => (C.gold, 'Connecting…'),
      _ => (C.bad, 'Offline'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
      ],
    );
  }
}
