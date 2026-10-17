/// Connection to the Quarkus backend over WebSocket, with automatic reconnect.
/// After reconnecting, the session re-sends "hello" with the same playerId and the server
/// gives the seat back (a bot plays for the player while they are away).
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection.dart';

class WsGameConnection implements GameConnection {
  WsGameConnection(this.url) {
    _open();
  }

  final Uri url;
  final StreamController<Json> _controller = StreamController.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _keepAlive;
  int _attempt = 0;
  bool _closed = false;

  @override
  Stream<Json> get messages => _controller.stream;

  Future<void> _open() async {
    if (_closed) return;
    final channel = WebSocketChannel.connect(url);
    _channel = channel;
    try {
      await channel.ready;
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    _attempt = 0;
    _emit({'type': 'connection', 'status': 'connected'});
    _sub = channel.stream.listen(
      (data) {
        try {
          _emit(jsonDecode(data as String) as Json);
        } on FormatException {
          // Ignore malformed frames.
        }
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 25), (_) => send({'type': 'ping'}));
  }

  void _scheduleReconnect() {
    _sub?.cancel();
    _keepAlive?.cancel();
    _channel = null;
    if (_closed) return;
    _emit({'type': 'connection', 'status': 'reconnecting'});
    final delayMs = [500, 1000, 2000, 4000, 8000][_attempt.clamp(0, 4)];
    _attempt++;
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: delayMs), _open);
  }

  void _emit(Json m) {
    if (!_controller.isClosed) _controller.add(m);
  }

  @override
  void send(Json message) {
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    _keepAlive?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _emit({'type': 'connection', 'status': 'closed'});
    await _controller.close();
  }
}
