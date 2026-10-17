/// In-process game server: a Dart twin of the Quarkus RoomService/Room/GameSocket that speaks the
/// same JSON protocol. The phone runs it for:
///  * offline play vs bots,
///  * hosting a Bluetooth table (remote guests attach through [attach]),
///  * the mock online backend ([LocalServerOptions.simulateOnline]) until the real server is used.
library;

import 'dart:async';
import 'dart:math';

import '../engine/action.dart';
import '../engine/bot.dart';
import '../engine/game.dart';
import '../engine/view.dart';
import 'connection.dart';

class LocalServerOptions {
  const LocalServerOptions({
    this.botDelay = const Duration(milliseconds: 700),
    this.roundPause = const Duration(seconds: 3),
    this.quickMatchWait = const Duration(seconds: 4),
    this.botLevel = BotLevel.normal,
    this.simulateOnline = false,
  });

  final Duration botDelay;
  final Duration roundPause;
  final Duration quickMatchWait;
  final BotLevel botLevel;

  /// Mock backend: quick match "finds" online players and unknown room codes open a friend's table.
  final bool simulateOnline;
}

/// Server-side handle for one connected client.
class ServerClient {
  ServerClient._(this._server, this._deliver);

  final LocalServer _server;
  final void Function(Json) _deliver;
  String? playerId;
  String name = 'Player';
  bool _closed = false;

  /// Feed a message from the client into the server.
  void receive(Json message) {
    if (_closed) return;
    scheduleMicrotask(() => _server._handle(this, message));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _server._disconnected(this);
  }

  void _send(Json message) {
    if (!_closed) _deliver(message);
  }
}

class LocalServer {
  LocalServer({this.options = const LocalServerOptions(), Random? random}) : _random = random ?? Random();

  final LocalServerOptions options;
  final Random _random;
  final Map<String, ServerClient> _clientByPlayer = {};
  final Map<String, _Room> _rooms = {};
  final Map<String, String> _roomOfPlayer = {};
  int _nextId = 0;
  bool _disposed = false;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// In-process client connection (used by this phone's own UI).
  GameConnection connect() => _LocalConnection(this);

  /// Attach a remote client (e.g. a Bluetooth guest); [deliver] sends messages to it.
  ServerClient attach(void Function(Json) deliver) => ServerClient._(this, deliver);

  Iterable<String> get roomCodes => _rooms.keys;

  void dispose() {
    _disposed = true;
    for (final r in _rooms.values) {
      r.dispose();
    }
    _rooms.clear();
  }

  // ---------------------------------------------------------------- message handling

  void _handle(ServerClient client, Json msg) {
    if (_disposed) return;
    final type = msg['type'];
    try {
      if (type == 'hello') {
        _hello(client, msg);
        return;
      }
      final playerId = client.playerId;
      if (playerId == null) throw IllegalMoveException('Say hello first');
      final name = _cleanName(msg['name'] as String? ?? client.name);
      switch (type) {
        case 'quickMatch':
          _quickMatch(playerId, name);
        case 'createRoom':
          _createRoom(playerId, name);
        case 'joinRoom':
          _joinRoom(playerId, name, msg['code'] as String? ?? '');
        case 'addBot':
          _roomOf(playerId).addBot(playerId);
        case 'startGame':
          _roomOf(playerId).start(playerId);
        case 'leaveRoom':
          _leave(playerId);
          client._send({'type': 'left'});
        case 'ping':
          client._send({'type': 'pong'});
        default:
          final action = GameAction.fromJson(msg);
          if (action == null) throw IllegalMoveException('Unknown message type: $type');
          _roomOf(playerId).act(playerId, action);
      }
    } on IllegalMoveException catch (e) {
      client._send({'type': 'error', 'message': e.message});
    } on ArgumentError catch (e) {
      client._send({'type': 'error', 'message': '${e.message}'});
    } on TypeError {
      client._send({'type': 'error', 'message': 'Bad request'});
    }
  }

  void _hello(ServerClient client, Json msg) {
    var playerId = msg['playerId'] as String? ?? '';
    if (playerId.isEmpty || playerId.length > 64) playerId = 'p${_random.nextInt(1 << 32)}-${_nextId++}';
    client
      ..playerId = playerId
      ..name = _cleanName(msg['name'] as String? ?? '');
    final old = _clientByPlayer[playerId];
    if (old != null && old != client) old._closed = true;
    _clientByPlayer[playerId] = client;
    client._send({'type': 'welcome', 'playerId': playerId, 'name': client.name});
    final room = _currentRoom(playerId);
    if (room != null) {
      room.setConnected(playerId, true);
      room.resend(playerId);
    }
  }

  void _disconnected(ServerClient client) {
    final id = client.playerId;
    if (id == null || _clientByPlayer[id] != client) return;
    _clientByPlayer.remove(id);
    _currentRoom(id)?.setConnected(id, false);
  }

  void _quickMatch(String playerId, String name) {
    _leave(playerId);
    final open = _rooms.values.where((r) => r.isPublic && r.hasFreeSeat).toList();
    _Room room;
    if (open.isNotEmpty) {
      room = open.first;
    } else {
      room = _newRoom(isPublic: true);
      if (options.simulateOnline) room.simulateArrivals(options.quickMatchWait);
      room.later(options.quickMatchWait, room.startGame);
    }
    _seat(room, playerId, name);
  }

  void _createRoom(String playerId, String name) {
    _leave(playerId);
    _seat(_newRoom(isPublic: false), playerId, name);
  }

  void _joinRoom(String playerId, String name, String rawCode) {
    final code = rawCode.trim().toUpperCase();
    var room = _rooms[code];
    if (room == null && options.simulateOnline && code.length == 5) {
      // Mock backend: pretend a friend is already waiting at this table and starts it shortly.
      room = _newRoom(isPublic: false, code: code)..seatSimulatedHost();
      room.later(options.quickMatchWait, room.startGame);
    }
    if (room == null) throw IllegalMoveException('No table with code $rawCode');
    if (room.seatOf(playerId) != -1) {
      room.setConnected(playerId, true);
      return;
    }
    if (!room.hasFreeSeat) throw IllegalMoveException('That table is full or already playing');
    _leave(playerId);
    _seat(room, playerId, name);
  }

  void _leave(String playerId) {
    final code = _roomOfPlayer.remove(playerId);
    final room = code == null ? null : _rooms[code];
    if (room == null) return;
    room.leave(playerId);
    if (!room.hasConnectedHumans) {
      room.dispose();
      _rooms.remove(code);
    }
  }

  void _seat(_Room room, String playerId, String name) {
    _roomOfPlayer[playerId] = room.code;
    if (!room.join(playerId, name)) {
      _roomOfPlayer.remove(playerId);
      throw IllegalMoveException('Could not take a seat');
    }
  }

  _Room _newRoom({required bool isPublic, String? code}) {
    while (code == null || _rooms.containsKey(code)) {
      code = String.fromCharCodes(List.generate(5, (_) => _codeChars.codeUnitAt(_random.nextInt(_codeChars.length))));
    }
    final room = _Room(code, isPublic, this);
    _rooms[code] = room;
    return room;
  }

  _Room? _currentRoom(String playerId) {
    final code = _roomOfPlayer[playerId];
    return code == null ? null : _rooms[code];
  }

  _Room _roomOf(String playerId) => _currentRoom(playerId) ?? (throw IllegalMoveException('You are not at a table'));

  void _sendTo(String playerId, Json message) => _clientByPlayer[playerId]?._send(message);

  static String _cleanName(String name) {
    var n = name.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    if (n.isEmpty) n = 'Player';
    return n.length > 16 ? n.substring(0, 16) : n;
  }
}

class _Seat {
  _Seat(this.playerId, this.name, {required this.bot}) : connected = !bot;

  final String playerId;
  final String name;
  final bool bot;

  /// Shown as a person in the lobby although a bot plays it (mock online players).
  bool looksHuman = false;
  bool connected;

  bool get autoPlay => bot || !connected;
}

class _Room {
  _Room(this.code, this.isPublic, this._server) : _bot = Bot(_server.options.botLevel, _server._random);

  static const _botNames = ['Arjun', 'Priya', 'Kabir', 'Meera', 'Ravi', 'Anika', 'Dev', 'Isha'];
  static const _onlineNames = ['Rahul_07', 'Sneha', 'Vikram', 'Pooja22', 'Aditya', 'Neha', 'Karan', 'Divya'];

  final String code;
  final bool isPublic;
  final LocalServer _server;
  final Bot _bot;
  final List<_Seat?> _seats = List.filled(Game.seats, null);
  final List<Timer> _timers = [];
  String? _host;
  bool _playing = false;
  Game? _game;
  int _version = 0;

  bool get hasFreeSeat => !_playing && _seats.contains(null);

  bool get hasConnectedHumans => _seats.any((s) => s != null && !s.bot && s.connected);

  int seatOf(String playerId) => _seats.indexWhere((s) => s?.playerId == playerId);

  bool join(String playerId, String name) {
    if (seatOf(playerId) != -1) return true;
    final free = _seats.indexOf(null);
    if (_playing || free == -1) return false;
    _seats[free] = _Seat(playerId, name, bot: false);
    _host ??= playerId;
    _changed();
    if (!_seats.contains(null) && isPublic) startGame();
    return true;
  }

  void addBot(String requester) {
    _requireHost(requester);
    final free = _seats.indexOf(null);
    if (free == -1) throw IllegalMoveException('Table is full');
    _seats[free] = _Seat('bot-$code-$free', '${_freeName(_botNames)} (bot)', bot: true);
    _changed();
  }

  void start(String requester) {
    _requireHost(requester);
    startGame();
  }

  void startGame() {
    if (_playing || !hasConnectedHumans) return;
    for (var i = 0; i < _seats.length; i++) {
      _seats[i] ??= _Seat('bot-$code-$i', '${_freeName(_botNames)} (bot)', bot: true);
    }
    _playing = true;
    _game = Game(_server._random);
    _changed();
  }

  /// Mock online: other "players" trickle into the quick-match table.
  void simulateArrivals(Duration window) {
    final arrivals = 1 + _server._random.nextInt(2);
    for (var i = 1; i <= arrivals; i++) {
      later(window * (i / (arrivals + 1)), () {
        final free = _seats.indexOf(null);
        if (_playing || free == -1) return;
        _seats[free] = _Seat('sim-$code-$free', _freeName(_onlineNames), bot: true)..looksHuman = true;
        _changed();
      });
    }
  }

  /// Mock online: a friend who created this table is already sitting at it.
  void seatSimulatedHost() {
    _seats[0] = _Seat('sim-$code-0', _freeName(_onlineNames), bot: true)..looksHuman = true;
  }

  void act(String playerId, GameAction action) {
    final game = _game ?? (throw IllegalMoveException('Game has not started'));
    final seat = seatOf(playerId);
    if (seat == -1) throw IllegalMoveException('You are not seated here');
    game.apply(seat, action);
    _changed();
  }

  void setConnected(String playerId, bool connected) {
    final seat = seatOf(playerId);
    if (seat == -1) return;
    _seats[seat]!.connected = connected;
    _changed();
  }

  void leave(String playerId) {
    final seat = seatOf(playerId);
    if (seat == -1) return;
    _seats[seat] = _playing ? _Seat('bot-$code-$seat', _seats[seat]!.name, bot: true) : null;
    if (_host == playerId) {
      _host = _seats.where((s) => s != null && !s.bot).map((s) => s!.playerId).firstOrNull;
    }
    _changed();
  }

  void resend(String playerId) {
    final seat = seatOf(playerId);
    if (seat == -1) return;
    _server._sendTo(playerId, {'type': 'room', 'room': _info(seat).toJson()});
    final game = _game;
    if (game != null) _server._sendTo(playerId, {'type': 'state', 'view': game.view(seat).toJson()});
  }

  void later(Duration delay, void Function() f) {
    late Timer t;
    t = Timer(delay, () {
      _timers.remove(t);
      if (!_server._disposed) f();
    });
    _timers.add(t);
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  // ---------------------------------------------------------------- internals

  void _changed() {
    _version++;
    for (var i = 0; i < _seats.length; i++) {
      final s = _seats[i];
      if (s == null || s.bot || !s.connected) continue;
      resend(s.playerId);
    }
    _scheduleAutomaticMove();
  }

  void _scheduleAutomaticMove() {
    final game = _game;
    if (game == null || !hasConnectedHumans) return;
    final v = _version;
    if (game.phase == Phase.roundOver) {
      later(_server.options.roundPause, () {
        if (v != _version || game.phase != Phase.roundOver) return;
        game.nextRound();
        _changed();
      });
    } else if (game.phase != Phase.matchOver && _seats[game.turn]!.autoPlay) {
      // Give players time to see who took the last trick before the next lead.
      final newTrick = game.phase == Phase.playing && game.trickEmpty && game.tricksPlayed > 0;
      later(_server.options.botDelay * (newTrick ? 2 : 1), () {
        if (v != _version || game.phase == Phase.matchOver) return;
        final seat = game.turn;
        if (seat < 0 || !_seats[seat]!.autoPlay) return;
        game.apply(seat, _bot.decide(game.view(seat)));
        _changed();
      });
    }
  }

  RoomInfo _info(int yourSeat) {
    final hostSeat = _seats.indexWhere((s) => s != null && s.playerId == _host);
    return RoomInfo(code, isPublic, hostSeat, _playing ? 'PLAYING' : 'WAITING', [
      for (var i = 0; i < _seats.length; i++)
        _seats[i] == null
            ? null
            : SeatInfo(
                i,
                _seats[i]!.name,
                _seats[i]!.bot && !_seats[i]!.looksHuman,
                _seats[i]!.bot || _seats[i]!.connected,
              ),
    ], yourSeat);
  }

  void _requireHost(String playerId) {
    if (playerId != _host) throw IllegalMoveException('Only the host can do that');
    if (_playing) throw IllegalMoveException('Game already started');
  }

  String _freeName(List<String> names) {
    final taken = _seats.whereType<_Seat>().map((s) => s.name.replaceAll(' (bot)', '')).toSet();
    final free = names.where((n) => !taken.contains(n)).toList();
    return free[_server._random.nextInt(free.length)];
  }
}

class _LocalConnection implements GameConnection {
  _LocalConnection(LocalServer server) {
    _client = server.attach((m) {
      if (!_controller.isClosed) _controller.add(m);
    });
    scheduleMicrotask(() => _controller.add({'type': 'connection', 'status': 'connected'}));
  }

  late final ServerClient _client;
  final StreamController<Json> _controller = StreamController.broadcast();

  @override
  Stream<Json> get messages => _controller.stream;

  @override
  void send(Json message) => _client.receive(message);

  @override
  Future<void> close() async {
    _client.close();
    await _controller.close();
  }
}
