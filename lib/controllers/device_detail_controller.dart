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

    ever<MqttEvent?>(_mqtt.lastEventRx, (ev) {
      if (ev == null) return;

      // Filtra: solo eventi del deviceId attuale
      if (!ev.topic.contains('/$deviceId/')) return;

      if (ev.isTelemetry) {
        final sample = _parseTelemetry(ev);
        if (sample != null) {
          current.value = sample;

          // Aggiungi allo storico (cap per non crescere infinito)
          history.add(sample);
          if (history.length > 2000) {
            history.removeRange(0, history.length - 2000);
          }
        }
      } else if (ev.isAlarm) {
        alarmText.value = ev.json?['message']?.toString() ?? ev.raw;
      }
    });
  }

  Future<void> _loadHistory() async {
    isLoading.value = true;
    try {
      // Se vuoi ultime 24h: fetchHistory(deviceId, hours: 24)
      final list = await _history.fetchHistory(deviceId);
      history.assignAll(list);
      if (list.isNotEmpty) current.value = list.last;
    } finally {
      isLoading.value = false;
    }
  }

  SensorSample? _parseTelemetry(MqttEvent ev) {
    final j = ev.json;
    if (j == null) return null;

    // 1) Gestione wrapper: se esiste "data" e sembra una mappa, usiamola come payload
    final dynamic dataDyn = j['data'];
    final Map<String, dynamic> payload =
    (dataDyn is Map) ? dataDyn.cast<String, dynamic>() : j;

    // 2) Timestamp robusto: preferisci wrapper ts, poi payload ts
    DateTime ts = DateTime.now();
    dynamic tsv = j['ts'] ?? payload['ts'];

    if (tsv is int) {
      // ms epoch
      ts = DateTime.fromMillisecondsSinceEpoch(tsv);
    } else if (tsv is num) {
      ts = DateTime.fromMillisecondsSinceEpoch(tsv.toInt());
    } else if (tsv is String) {
      ts = DateTime.tryParse(tsv) ?? DateTime.now();
    }

    double? d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    return SensorSample(
      deviceId: deviceId,
      ts: ts,
      temperature: d(payload['temperature']),
      humidity: d(payload['humidity']),
      chlorophyll: d(payload['chlorophyll']),
    );
  }
}
