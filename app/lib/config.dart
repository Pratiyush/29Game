/// Build-time configuration:
///   flutter run                                   -> online mode uses the in-app mock backend
///   flutter run --dart-define=BACKEND=server \
///               --dart-define=SERVER_URL=ws://192.168.1.10:8080/ws   -> real Quarkus backend
library;

class AppConfig {
  static const backend = String.fromEnvironment('BACKEND', defaultValue: 'mock');

  /// 10.0.2.2 is the host machine as seen from the Android emulator.
  static const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'ws://10.0.2.2:8080/ws');

  static bool get useMockBackend => backend != 'server';
}
