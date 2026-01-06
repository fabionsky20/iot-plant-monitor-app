import 'package:get/get.dart';
import '../data/history_repository.dart';
import '../data/mqtt_repository.dart';
import '../models/sensor_sample.dart';
import 'mqtt_controller.dart';

class DeviceDetailController extends GetxController {
  final String deviceId;
  final HistoryRepository _history;
  final MqttController _mqtt;

  DeviceDetailController({
    required this.deviceId,
    required HistoryRepository history,
    required MqttController mqtt,
  })  : _history = history,
        _mqtt = mqtt;

  final isLoading = true.obs;

  final history = <SensorSample>[].obs;
  final current = Rxn<SensorSample>();

  final alarmText = RxnString();

  @override
  void onInit() {
    super.onInit();

    _loadHistory();
    _mqtt.openDevice(deviceId);

    // ascolta ultimi eventi MQTT
    ever<MqttEvent?>(_mqtt.lastEventRx, (ev) {
      if (ev == null) return;

      print("📲 Flutter got event topic=${ev.topic} raw=${ev.raw}");

      // Filtra: solo eventi del deviceId attuale
      if (!ev.topic.contains('/$deviceId/')) return;

      if (ev.isTelemetry) {
        final sample = _parseTelemetry(ev);
        if (sample != null) {
          current.value = sample;

          print("✅ current updated T=${sample.temperature} H=${sample.humidity} C=${sample.chlorophyll}");

          history.add(sample);
        }
      } else if (ev.isAlarm) {
        alarmText.value = ev.json?['message']?.toString() ?? ev.raw;
      }
    });
  }

  Future<void> _loadHistory() async {
    isLoading.value = true;
    try {
      final list = await _history.fetchLast24h(deviceId);
      history.assignAll(list);
      if (list.isNotEmpty) current.value = list.last;
    } finally {
      isLoading.value = false;
    }
  }

  //parsing mqtt signal
  SensorSample? _parseTelemetry(MqttEvent ev) {
    final j = ev.json;
    if (j == null) return null;

    DateTime ts = DateTime.now();
    final tsv = j['ts'];

    if (tsv is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(tsv);
    } else if (tsv is String) {
      ts = DateTime.tryParse(tsv) ?? DateTime.now();
    }

    double? d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    return SensorSample(
      deviceId: deviceId,
      ts: ts,
      temperature: d(j['temperature']),
      humidity: d(j['humidity']),
      chlorophyll: d(j['chlorophyll']),
    );
  }

}
