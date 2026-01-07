import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_sample.dart';

class HistoryRepository {
  static const String backendHost =
  String.fromEnvironment('BACKEND_HOST', defaultValue: '84.8.255.56');
  static const int backendPort =
  int.fromEnvironment('BACKEND_PORT', defaultValue: 3000);

  static String get baseUrl => 'http://$backendHost:$backendPort';


  Future<List<SensorSample>> fetchHistory(
      String deviceId, {
        int? hours, // null = tutto (limitato dal backend)
        int limit = 500,
      }) async {
    final q = <String, String>{'limit': '$limit'};
    if (hours != null) q['hours'] = '$hours';

    final uri = Uri.parse('$baseUrl/devices/$deviceId/history')
        .replace(queryParameters: q);

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
