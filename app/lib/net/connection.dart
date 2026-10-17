/// Transport-agnostic link to a game host (Quarkus server, in-process server, or Bluetooth host).
/// Messages are the JSON maps described in docs/PROTOCOL.md.
library;

typedef Json = Map<String, dynamic>;

abstract class GameConnection {
  /// Messages from the host: welcome, room, state, error, left, pong, plus the local-only
  /// {"type": "connection", "status": "connected" | "reconnecting" | "closed"}.
  Stream<Json> get messages;

  void send(Json message);

  Future<void> close();
}

class SeatInfo {
  const SeatInfo(this.seat, this.name, this.bot, this.connected);

  final int seat;
  final String name;
  final bool bot;
  final bool connected;

  factory SeatInfo.fromJson(Json j) =>
      SeatInfo(j['seat'] as int, j['name'] as String, j['bot'] as bool, j['connected'] as bool);

  Json toJson() => {'seat': seat, 'name': name, 'bot': bot, 'connected': connected};
}

class RoomInfo {
  const RoomInfo(this.code, this.isPublic, this.hostSeat, this.status, this.seats, this.yourSeat);

  final String code;
  final bool isPublic;
  final int hostSeat;

  /// WAITING or PLAYING.
  final String status;
  final List<SeatInfo?> seats;
  final int yourSeat;

  bool get playing => status == 'PLAYING';
  bool get amHost => hostSeat == yourSeat;

  factory RoomInfo.fromJson(Json j) => RoomInfo(
    j['code'] as String,
    j['isPublic'] as bool,
    j['hostSeat'] as int,
    j['status'] as String,
    (j['seats'] as List).map((s) => s == null ? null : SeatInfo.fromJson(s as Json)).toList(),
    j['yourSeat'] as int,
  );

  Json toJson() => {
    'code': code,
    'isPublic': isPublic,
    'hostSeat': hostSeat,
    'status': status,
    'seats': seats.map((s) => s?.toJson()).toList(),
    'yourSeat': yourSeat,
  };
}
