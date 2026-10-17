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
    this.avatar = -1,
    this.server,
    this.nearbyHost,
  }) {
    _sub = connection.messages.listen(_onMessage);
  }

  /// Play against bots on this phone. No network at all.
  factory TableSession.offline({
    required String name,
    required String playerId,
    required BotLevel level,
    int avatar = -1,
    Duration botDelay = const Duration(milliseconds: 700),
  }) {
    final server = LocalServer(
      options: LocalServerOptions(botLevel: level, quickMatchWait: Duration.zero, botDelay: botDelay),
    );
    return TableSession._(
      kind: SessionKind.offline,
      connection: server.connect(),
      name: name,
      playerId: playerId,
      avatar: avatar,
      intent: const {'type': 'quickMatch'},
      server: server,
    );
  }

  /// Online through the Quarkus backend, or the in-app mock backend (see [AppConfig]).
  /// [intent] is a lobby message: quickMatch, createRoom or joinRoom.
  factory TableSession.online({required String name, required String playerId, required Json intent, int avatar = -1}) {
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
      avatar: avatar,
      intent: intent,
      server: server,
    );
  }

  /// Host a table that nearby phones join over Bluetooth / Wi-Fi Direct.
  factory TableSession.nearbyHost({
    required String name,
    required String playerId,
    required BotLevel level,
    int avatar = -1,
    Duration botDelay = const Duration(milliseconds: 700),
  }) {
    final server = LocalServer(
      options: LocalServerOptions(botLevel: level, botDelay: botDelay),
    );
    return TableSession._(
      kind: SessionKind.nearbyHost,
      connection: server.connect(),
      name: name,
      playerId: playerId,
      avatar: avatar,
      intent: const {'type': 'createRoom'},
      server: server,
      nearbyHost: NearbyHost(server, name),
    );
  }

  factory TableSession.nearbyGuest({
    required String name,
    required String playerId,
    required NearbyTable table,
    int avatar = -1,
  }) {
    return TableSession._(
      kind: SessionKind.nearbyGuest,
      connection: NearbyGuestConnection(table, name),
      name: name,
      playerId: playerId,
      avatar: avatar,
      intent: {'type': 'joinRoom', 'code': table.code},
    );
  }

  final SessionKind kind;
  final GameConnection connection;
  final String name;
  final String playerId;

  /// Portrait index sent with hello; -1 lets the host pick.
  final int avatar;
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

  final StreamController<EmoteEvent> _emotes = StreamController.broadcast();

  /// Quick reactions from anyone at the table (including bots), to float over their seat.
  Stream<EmoteEvent> get emotes => _emotes.stream;

  void emote(String emote) => connection.send({'type': 'emote', 'emote': emote});

  String seatName(int seat) {
    if (seat == room?.yourSeat) return 'You';
    return (room?.seats[seat]?.name ?? 'Seat ${seat + 1}').replaceAll(' (bot)', '');
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
          connection.send({'type': 'hello', 'playerId': playerId, 'name': name, 'avatar': avatar});
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
      case 'emote':
        _emotes.add(EmoteEvent(m['seat'] as int, m['emote'] as String));
        return;
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
    _emotes.close();
    super.dispose();
  }
}

class EmoteEvent {
  const EmoteEvent(this.seat, this.emote);

  final int seat;
  final String emote;
}
