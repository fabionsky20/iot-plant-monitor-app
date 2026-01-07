// FILE: lib/data/mqtt_repository.dart
import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class MqttRepository {
  static const String backendHost =
  String.fromEnvironment('BACKEND_HOST', defaultValue: '84.8.255.56');

  static const int backendPort =
  int.fromEnvironment('BACKEND_PORT', defaultValue: 3000);

  static const String wsPath =
  String.fromEnvironment('BACKEND_WS_PATH', defaultValue: '/');

  static const String topicPrefix = 'plantform';

  final _events = StreamController<MqttEvent>.broadcast();
  Stream<MqttEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  bool _ready = false;

  bool get isConnected => _ready;

  String telemetryTopic(String deviceId) => '$topicPrefix/$deviceId/telemetry';
  String alarmTopic(String deviceId) => '$topicPrefix/$deviceId/alarm';

  Uri _wsUriForDevice(String deviceId) {
    final path = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    return Uri(
      scheme: 'ws',
      host: backendHost,
      port: backendPort,
      path: path,
      queryParameters: {'deviceId': deviceId},
    );
  }

  Future<void> connectIfNeeded() async {
    // ✅ Segna come "ready": così MqttController non si blocca
    _ready = true;
  }

  Future<void> subscribeToDevice(String deviceId) async {
    // chiudi eventuale connessione precedente
    await disconnectWsOnly();

    final uri = _wsUriForDevice(deviceId);
    print('🔌 WS connect -> $uri');

    final ch = WebSocketChannel.connect(uri);
    _channel = ch;

    _wsSub = ch.stream.listen(
          (event) {
        final text = event.toString();
        // print('📩 WS raw=$text'); // scommenta se vuoi debug

        Map<String, dynamic>? msg;
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) msg = decoded;
        } catch (_) {
          msg = null;
        }
        if (msg == null) return;

        final type = msg['type']?.toString();
        final devId = msg['deviceId']?.toString() ?? deviceId;

        final topic = (type == 'alarm')
            ? alarmTopic(devId)
            : telemetryTopic(devId);

        final data = msg['data'];
        Map<String, dynamic>? json;
        String raw;

        if (data is Map<String, dynamic>) {
          json = data;
          raw = jsonEncode(data);
        } else {
          json = null;
          raw = data?.toString() ?? '';
        }

        _events.add(MqttEvent(topic: topic, raw: raw, json: json));
      },
      onError: (e) {
        print('❌ WS error: $e');
      },
      onDone: () {
        print('⚠️ WS closed');
      },
    );
  }

  Future<void> disconnectWsOnly() async {
    await _wsSub?.cancel();
    _wsSub = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> disconnect() async {
    await disconnectWsOnly();
    _ready = false;
  }
}

class MqttEvent {
  final String topic;
  final String raw;
  final Map<String, dynamic>? json;

  MqttEvent({
    required this.topic,
    required this.raw,
    required this.json,
  });

  bool get isTelemetry => topic.endsWith('/telemetry');
  bool get isAlarm => topic.endsWith('/alarm');
}
