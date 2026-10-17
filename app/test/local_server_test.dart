import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game29/engine/bot.dart';
import 'package:game29/engine/view.dart';
import 'package:game29/net/connection.dart';
import 'package:game29/net/local_server.dart';
import 'package:game29/net/session.dart';

const fast = LocalServerOptions(
  botDelay: Duration(milliseconds: 1),
  roundPause: Duration(milliseconds: 1),
  quickMatchWait: Duration(milliseconds: 5),
);

/// Drives a connection with the bot until the first round ends.
Future<PlayerView> playOneRound(GameConnection c) async {
  final bot = Bot(BotLevel.normal, randomForTest);
  final done = Completer<PlayerView>();
  final sub = c.messages.listen((m) {
    if (m['type'] == 'error') fail('server error: ${m['message']}');
    if (m['type'] != 'state' || done.isCompleted) return;
    final v = PlayerView.fromJson(m['view'] as Json);
    if (v.phase == Phase.roundOver || v.phase == Phase.matchOver) {
      done.complete(v);
    } else if (v.myTurn) {
      c.send(bot.decide(v).toJson());
    }
  });
  final v = await done.future.timeout(const Duration(seconds: 10));
  await sub.cancel();
  return v;
}

final randomForTest = Random(1);

void main() {
  test('offline quick match fills with bots and plays a full round', () async {
    final server = LocalServer(options: fast);
    final c = server.connect();
    c.messages.where((m) => m['type'] == 'connection').first.then((_) {
      c.send({'type': 'hello', 'name': 'Asha'});
      c.send({'type': 'quickMatch'});
    });
    final v = await playOneRound(c);
    expect(v.teamPoints[0] + v.teamPoints[1], 28);
    expect(v.lastRound, isNotNull);
    server.dispose();
  });

  test('a remote guest (as over Bluetooth) joins the host table by code', () async {
    final server = LocalServer(options: fast);
    final host = server.connect();
    final hostRooms = host.messages.where((m) => m['type'] == 'room').map((m) => RoomInfo.fromJson(m['room'] as Json));
    final firstRoom = hostRooms.first;
    host.send({'type': 'hello', 'name': 'Host'});
    host.send({'type': 'createRoom'});
    final code = (await firstRoom).code;

    final guestInbox = StreamController<Json>.broadcast();
    final guest = server.attach(guestInbox.add);
    final guestRoom = guestInbox.stream.where((m) => m['type'] == 'room').first;
    guest.receive({'type': 'hello', 'name': 'Guest'});
    guest.receive({'type': 'joinRoom', 'code': code.toLowerCase()});
    final joined = RoomInfo.fromJson((await guestRoom)['room'] as Json);
    expect(joined.yourSeat, 1);
    expect(joined.seats[0]!.name, 'Host');

    final guestState = guestInbox.stream.where((m) => m['type'] == 'state').first;
    host.send({'type': 'startGame'});
    final v = PlayerView.fromJson((await guestState)['view'] as Json);
    expect(v.hand.length, 4);
    server.dispose();
  });

  test('non-host cannot start; unknown codes are rejected without the mock', () async {
    final server = LocalServer(options: fast);
    final c = server.connect();
    final err = c.messages.where((m) => m['type'] == 'error').first;
    c.send({'type': 'hello', 'name': 'X'});
    c.send({'type': 'joinRoom', 'code': 'ZZZZZ'});
    expect((await err)['message'], contains('ZZZZZ'));
    server.dispose();
  });

  test('mock online backend: quick match finds players and the session reaches the table', () async {
    final s = TableSession.online(name: 'Asha', playerId: 'p1', intent: const {'type': 'quickMatch'});
    final playing = Completer<void>();
    s.addListener(() {
      if (s.room?.playing == true && s.view != null && !playing.isCompleted) playing.complete();
    });
    await playing.future.timeout(const Duration(seconds: 10));
    expect(s.room!.seats.where((x) => x != null).length, 4);
    expect(s.view!.hand.length, 4);
    s.dispose();
  });
}
