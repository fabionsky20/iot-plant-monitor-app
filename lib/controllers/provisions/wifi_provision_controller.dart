import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'provision_controller.dart';

class WifiProvisionController extends GetxController {
  // UI state
  final ssid = ''.obs;
  final password = ''.obs;
  final status = 'IDLE'.obs;

  // comunicazione con esp32, UUID
  static final Guid provisioningServiceUuid =
  Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  static final Guid provisioningCharUuid =
  Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");

  ProvisionController get bleController => Get.find<ProvisionController>();

  void setSsid(String v) => ssid.value = v.trim();
  void setPassword(String v) => password.value = v;

  Future<BluetoothDevice?> _getConnectedDevice() async {
    final id = bleController.connectedDeviceId.value;
    if (id.isEmpty) return null;

    // flutter_blue_plus espone i device già connessi
    final devices = await FlutterBluePlus.connectedDevices;
    for (final d in devices) {
      if (d.remoteId.str == id) return d;
    }
    return null;
  }

  Future<BluetoothCharacteristic?> _findProvisioningChar(BluetoothDevice device) async {
    // discover services
    final services = await device.discoverServices();

    for (final s in services) {
      if (s.uuid == provisioningServiceUuid) {
        for (final c in s.characteristics) {
          if (c.uuid == provisioningCharUuid) return c;
        }
      }
    }
    return null;
  }

  /// Invia SSID+PASSWORD all'ESP32 via BLE
  Future<void> sendWifiCredentials() async {
    final s = ssid.value;
    final p = password.value;

    if (s.isEmpty || p.isEmpty) {
      status.value = 'ERROR: SSID o password vuoti';
      return;
    }

    status.value = 'SENDING...';

    try {
      final device = await _getConnectedDevice();
      if (device == null) {
        status.value = 'ERROR: Nessun device BLE connesso';
        return;
      }

      final ch = await _findProvisioningChar(device);
      if (ch == null) {
        status.value = 'ERROR: Characteristic provisioning non trovata (UUID?)';
        return;
      }

      // Payload semplice: JSON
      final payload = jsonEncode({
        "type": "wifi",
        "ssid": s,
        "password": p,
      });

      // BLE spesso ha MTU limitato: qui mando tutto in uno, se serve poi chunkiamo.
      await ch.write(utf8.encode(payload), withoutResponse: false);

      status.value = 'SENT';
    } catch (e) {
      status.value = 'ERROR: $e';
    }
  }
}
