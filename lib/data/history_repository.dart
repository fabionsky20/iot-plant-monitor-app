import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_sample.dart';

class HistoryRepository {
  // Se testi su Android emulator: 10.0.2.2
  // Se testi su telefono: IP del tuo PC nella stessa rete (es: 192.168.1.50)
  static const String backendHost =
  String.fromEnvironment('BACKEND_HOST', defaultValue: '192.168.188.30');
  static const int backendPort =
  int.fromEnvironment('BACKEND_PORT', defaultValue: 3000);

  static String get baseUrl => 'http://$backendHost:$backendPort';


  Future<List<SensorSample>> fetchLast24h(String deviceId) async {
    final uri = Uri.parse('$baseUrl/devices/$deviceId/history?hours=24');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('History error ${res.statusCode}: ${res.body}');
    }

    final list = jsonDecode(res.body);
    if (list is! List) return [];

    return list.map<SensorSample>((e) {
      final m = (e as Map).cast<String, dynamic>();
      final ts = DateTime.tryParse(m['ts']?.toString() ?? '') ?? DateTime.now();

      double? d(dynamic v) => (v is num) ? v.toDouble() : null;

      return SensorSample(
        deviceId: deviceId,
        ts: ts,
        temperature: d(m['temperature']),
        humidity: d(m['humidity']),
        chlorophyll: d(m['chlorophyll']),
      );
    }).toList();
  }
}
