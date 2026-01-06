import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveSocket {
  WebSocketChannel? _channel;

  void connect({
    required String backendUrl,
    required String deviceId,
    required void Function(Map<String, dynamic>) onMessage,
  }) {
    final uri = Uri.parse('$backendUrl?deviceId=$deviceId');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen((event) {
      final decoded = jsonDecode(event);
      if (decoded is Map<String, dynamic>) {
        onMessage(decoded);
      }
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
