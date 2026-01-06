import 'dart:async';
import 'package:get/get.dart';
import '../data/mqtt_repository.dart';

class MqttController extends GetxController {
  final MqttRepository _repo;
  MqttController(this._repo);

  final isConnected = false.obs;
  final lastError = RxnString();

  /// Ultimo evento MQTT ricevuto
  final Rxn<MqttEvent> lastEventRx = Rxn<MqttEvent>();

  StreamSubscription<MqttEvent>? _sub;

  Future<void> ensureConnected() async {
    try {
      await _repo.connectIfNeeded();
      isConnected.value = _repo.isConnected;
      lastError.value = null;

      _sub ??= _repo.events.listen((e) {
        lastEventRx.value = e;
      });
    } catch (e) {
      lastError.value = e.toString();
      isConnected.value = false;
    }
  }

  Future<void> openDevice(String deviceId) async {
    await ensureConnected();
    if (!isConnected.value) return;
    await _repo.subscribeToDevice(deviceId);
  }

  @override
  void onClose() {
    _sub?.cancel();
    _repo.disconnect();
    super.onClose();
  }
}
