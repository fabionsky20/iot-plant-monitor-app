import 'package:get/get.dart';
import '../data/devices_repository.dart';

class SavedDevice {
  final String alias;
  final String deviceId; // remoteId.str
  final int createdAtMs;

  SavedDevice({
    required this.alias,
    required this.deviceId,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => {
    'alias': alias,
    'deviceId': deviceId,
    'createdAtMs': createdAtMs,
  };

  static SavedDevice fromJson(Map<String, dynamic> j) => SavedDevice(
    alias: (j['alias'] ?? '').toString(),
    deviceId: (j['deviceId'] ?? '').toString(),
    createdAtMs: (j['createdAtMs'] ?? 0) as int,
  );
}

class DevicesController extends GetxController {
  final _repo = DevicesRepository();
  final devices = <SavedDevice>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDevices();
  }

  Future<void> loadDevices() async {
    final raw = await _repo.load();
    final list = raw.map(SavedDevice.fromJson).toList();
    devices.assignAll(list);
  }

  Future<void> _persist() async {
    await _repo.save(devices.map((d) => d.toJson()).toList());
  }

  Future<void> addOrUpdate({required String alias, required String deviceId}) async {
    final a = alias.trim();
    if (a.isEmpty || deviceId.trim().isEmpty) return;

    final idx = devices.indexWhere((d) => d.deviceId == deviceId);
    if (idx >= 0) {
      // aggiorna alias se cambia
      final old = devices[idx];
      devices[idx] = SavedDevice(alias: a, deviceId: old.deviceId, createdAtMs: old.createdAtMs);
    } else {
      devices.add(SavedDevice(alias: a, deviceId: deviceId, createdAtMs: DateTime.now().millisecondsSinceEpoch));
    }
    await _persist();
  }

  Future<void> deleteById(String deviceId) async {
    devices.removeWhere((d) => d.deviceId == deviceId);
    await _persist();
  }

  Future<void> clearAll() async {
    devices.clear();
    await _persist();
  }

  Future<void> renameDevice(String deviceId, String newAlias) async {
    final a = newAlias.trim();
    if (a.isEmpty) return;

    final idx = devices.indexWhere((d) => d.deviceId == deviceId);
    if (idx < 0) return;

    final old = devices[idx];
    devices[idx] = SavedDevice(alias: a, deviceId: old.deviceId, createdAtMs: old.createdAtMs);
    await _persist();
  }

}
