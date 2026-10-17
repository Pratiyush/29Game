import 'dart:async';

import 'package:flutter/material.dart';

import '../net/session.dart';
import 'lobby_view.dart';
import 'table_view.dart';
import 'theme.dart';

/// Owns a [TableSession] for its lifetime: shows the lobby until the deal, then the table.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.session});

  final TableSession session;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final StreamSubscription<String> _errors;

  TableSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _errors = session.errors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    });
  }

  @override
  void dispose() {
    _errors.cancel();
    session.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final playing = session.room?.playing ?? false;
    final ok =
        !playing ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Leave the table?'),
                content: const Text('A bot will take over your seat.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                ],
              ),
            ) ==
            true;
    if (!ok || !mounted) return;
    session.leave();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: FeltBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                final room = session.room;
                final view = session.view;
                if (room != null && room.playing && view != null) {
                  return TableView(session: session, view: view, onLeave: _confirmLeave);
                }
                return LobbyView(session: session, onLeave: _confirmLeave);
              },
            ),
          ),
        ),
      ),
    );
  }
}
