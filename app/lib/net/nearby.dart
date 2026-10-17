/// Offline multiplayer over Bluetooth / Wi-Fi Direct using Google Nearby Connections (Android).
///
/// The host phone runs a [LocalServer] and advertises `hostName#roomCode`. Guests discover it,
/// connect, and exchange exactly the same JSON messages as with the online server — the host's
/// server is authoritative, so guests cannot cheat and bots fill any empty seats.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'connection.dart';
import 'local_server.dart';

const _serviceId = 'com.game29.table';
const _strategy = Strategy.P2P_STAR;

bool get nearbySupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> ensureNearbyPermissions() async {
  if (!nearbySupported) {
    throw UnsupportedError('Nearby play currently works on Android only.');
  }
  final statuses = await [
    Permission.location,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
  ].request();
  final denied = statuses.entries.where(
    (e) => e.value.isPermanentlyDenied || (e.value.isDenied && e.key != Permission.nearbyWifiDevices),
  );
  if (denied.isNotEmpty) {
    throw StateError('Bluetooth and location permissions are needed to play nearby.');
  }
}

Uint8List _encode(Json m) => Uint8List.fromList(utf8.encode(jsonEncode(m)));

Json? _decode(Payload p) {
  final bytes = p.bytes;
  if (p.type != PayloadType.BYTES || bytes == null) return null;
  try {
    return jsonDecode(utf8.decode(bytes)) as Json;
  } on FormatException {
    return null;
  }
}

/// Bridges nearby guests into the host's [LocalServer].
class NearbyHost {
  NearbyHost(this.server, this.hostName);

  final LocalServer server;
  final String hostName;
  final Map<String, ServerClient> _guests = {};
  bool _advertising = false;
  bool _starting = false;

  int get guestCount => _guests.length;

  Future<void> start(String roomCode) async {
    if (_advertising || _starting) return;
    _starting = true;
    try {
      await ensureNearbyPermissions();
      _advertising = await _advertise(roomCode);
    } finally {
      _starting = false;
    }
  }

  Future<bool> _advertise(String roomCode) {
    return Nearby().startAdvertising(
      '$hostName#$roomCode',
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: (id, info) {
        Nearby().acceptConnection(id, onPayLoadRecieved: _onPayload);
      },
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) {
          _guests[id] = server.attach((m) => Nearby().sendBytesPayload(id, _encode(m)));
        }
      },
      onDisconnected: (id) => _guests.remove(id)?.close(),
    );
  }

  void _onPayload(String endpointId, Payload payload) {
    final m = _decode(payload);
    if (m != null) _guests[endpointId]?.receive(m);
  }

  Future<void> stop() async {
    for (final g in _guests.values) {
      g.close();
    }
    _guests.clear();
    if (!nearbySupported) return;
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    _advertising = false;
  }
}

class NearbyTable {
  const NearbyTable(this.endpointId, this.hostName, this.code);

  final String endpointId;
  final String hostName;
  final String code;
}

/// Looks for tables hosted by phones nearby.
class NearbyDiscovery {
  final Map<String, NearbyTable> _found = {};
  final StreamController<List<NearbyTable>> _controller = StreamController.broadcast();

  Stream<List<NearbyTable>> get tables => _controller.stream;

  Future<void> start(String myName) async {
    await ensureNearbyPermissions();
    await Nearby().startDiscovery(
      myName,
      _strategy,
      serviceId: _serviceId,
      onEndpointFound: (id, name, serviceId) {
        final hash = name.lastIndexOf('#');
        if (hash <= 0) return;
        _found[id] = NearbyTable(id, name.substring(0, hash), name.substring(hash + 1));
        _controller.add(_found.values.toList());
      },
      onEndpointLost: (id) {
        _found.remove(id);
        _controller.add(_found.values.toList());
      },
    );
  }

  Future<void> stop() async {
    await Nearby().stopDiscovery();
    await _controller.close();
  }
}

/// A guest's link to a nearby host.
class NearbyGuestConnection implements GameConnection {
  NearbyGuestConnection(this.table, String myName) {
    _connect(myName);
  }

  final NearbyTable table;
  final StreamController<Json> _controller = StreamController.broadcast();
  bool _connected = false;

  @override
  Stream<Json> get messages => _controller.stream;

  Future<void> _connect(String myName) async {
    try {
      await Nearby().requestConnection(
        myName,
        table.endpointId,
        onConnectionInitiated: (id, info) {
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              final m = _decode(payload);
              if (m != null) _emit(m);
            },
          );
        },
        onConnectionResult: (id, status) {
          _connected = status == Status.CONNECTED;
          if (_connected) {
            _emit({'type': 'connection', 'status': 'connected'});
          } else {
            _emit({'type': 'error', 'message': 'The host did not accept the connection'});
          }
        },
        onDisconnected: (id) {
          _connected = false;
          _emit({'type': 'connection', 'status': 'closed'});
        },
      );
    } catch (e) {
      _emit({'type': 'error', 'message': 'Could not reach ${table.hostName}: $e'});
    }
  }

  void _emit(Json m) {
    if (!_controller.isClosed) _controller.add(m);
  }

  @override
  void send(Json message) {
    if (_connected) Nearby().sendBytesPayload(table.endpointId, _encode(message));
  }

  @override
  Future<void> close() async {
    if (_connected) await Nearby().disconnectFromEndpoint(table.endpointId);
    _connected = false;
    await _controller.close();
  }
}
