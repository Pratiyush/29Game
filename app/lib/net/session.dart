/// Client-side state for one table, independent of transport. Screens listen to it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../engine/action.dart';
import '../engine/bot.dart';
import '../engine/view.dart';
import 'connection.dart';
import 'local_server.dart';
import 'nearby.dart';
import 'ws_connection.dart';

enum SessionKind { offline, online, nearbyHost, nearbyGuest }

class TableSession extends ChangeNotifier {
  TableSession._({
    required this.kind,
    required this.connection,
    required this.name,
    required this.playerId,
    required this._intent,
    this.server,
    this.nearbyHost,
  }) {
    _sub = connection.messages.listen(_onMessage);
  }

  /// Play against bots on this phone. No network at all.
  factory TableSession.offline({required String name, required String playerId, required BotLevel level}) {
    final server = LocalServer(
      options: LocalServerOptions(botLevel: level, quickMatchWait: Duration.zero),
    );
    return TableSession._(
      kind: SessionKind.offline,
      connection: server.connect(),
      name: name,
      playerId: playerId,
      intent: const {'type': 'quickMatch'},
      server: server,
    );
  }

  /// Online through the Quarkus backend, or the in-app mock backend (see [AppConfig]).
  /// [intent] is a lobby message: quickMatch, createRoom or joinRoom.
  factory TableSession.online({required String name, required String playerId, required Json intent}) {
    LocalServer? server;
    final GameConnection connection;
    if (AppConfig.useMockBackend) {
      server = LocalServer(options: const LocalServerOptions(simulateOnline: true));
      connection = server.connect();
    } else {
      connection = WsGameConnection(Uri.parse(AppConfig.serverUrl));
    }
    return TableSession._(
      kind: SessionKind.online,
      connection: connection,
      name: name,
      playerId: playerId,
      intent: intent,
      server: server,
    );
  }

  /// Host a table that nearby phones join over Bluetooth / Wi-Fi Direct.
  factory TableSession.nearbyHost({required String name, required String playerId, required BotLevel level}) {
    final server = LocalServer(options: LocalServerOptions(botLevel: level));
    return TableSession._(
      kind: SessionKind.nearbyHost,
      connection: server.connect(),
      name: name,
      playerId: playerId,
      intent: const {'type': 'createRoom'},
      server: server,
      nearbyHost: NearbyHost(server, name),
    );
  }

  factory TableSession.nearbyGuest({required String name, required String playerId, required NearbyTable table}) {
    return TableSession._(
      kind: SessionKind.nearbyGuest,
      connection: NearbyGuestConnection(table, name),
      name: name,
      playerId: playerId,
      intent: {'type': 'joinRoom', 'code': table.code},
    );
  }

  final SessionKind kind;
  final GameConnection connection;
  final String name;
  final String playerId;
  final LocalServer? server;
  final NearbyHost? nearbyHost;
  final Json _intent;
  bool _intentSent = false;
  late final StreamSubscription<Json> _sub;

  RoomInfo? room;
  PlayerView? view;

  /// connecting | connected | reconnecting | closed
  String connectionStatus = 'connecting';
  bool left = false;

  final StreamController<String> _errors = StreamController.broadcast();

  /// Errors from the host (illegal move, bad room code...) to show as snackbars.
  Stream<String> get errors => _errors.stream;

  String seatName(int seat) {
    if (seat == room?.yourSeat) return 'You';
    return room?.seats[seat]?.name ?? 'Seat ${seat + 1}';
  }

  void act(GameAction action) => connection.send(action.toJson());

  void addBot() => connection.send({'type': 'addBot'});

  void startGame() => connection.send({'type': 'startGame'});

  void leave() => connection.send({'type': 'leaveRoom'});

  void _onMessage(Json m) {
    switch (m['type']) {
      case 'connection':
        connectionStatus = m['status'] as String;
        if (connectionStatus == 'connected') {
          connection.send({'type': 'hello', 'playerId': playerId, 'name': name});
        }
      case 'welcome':
        if (!_intentSent) {
          _intentSent = true;
          connection.send({..._intent, 'name': name});
        }
      case 'room':
        room = RoomInfo.fromJson(m['room'] as Json);
        if (kind == SessionKind.nearbyHost) {
          nearbyHost!.start(room!.code).catchError((Object e) => _errors.add('$e'));
        }
      case 'state':
        view = PlayerView.fromJson(m['view'] as Json);
      case 'left':
        left = true;
      case 'error':
        _errors.add(m['message'] as String);
        return;
      default:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    nearbyHost?.stop();
    connection.close();
    server?.dispose();
    _errors.close();
    super.dispose();
  }
}
