import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

import '../BLE_controller.dart';
import 'wifi_provision_controller.dart';
import 'sensors_provision_controller.dart';

class ProvisionPayloadController extends GetxController {
  final status = 'IDLE'.obs;

  ProvisionController get ble => Get.find<ProvisionController>();
  WifiProvisionController get wifi => Get.find<WifiProvisionController>();
  SensorsProvisionController get sensors => Get.find<SensorsProvisionController>();

  // riuso UUID già definiti nel WifiProvisionController (senza toccarlo)
  Guid get serviceUuid => WifiProvisionController.provisioningServiceUuid;
  Guid get rxUuid => WifiProvisionController.provisioningCharUuid;

  Future<BluetoothDevice?> _getConnectedDevice() async {
    final id = ble.connectedDeviceId.value;
    if (id.isEmpty) return null;

    final devices = await FlutterBluePlus.connectedDevices;
    for (final d in devices) {
      if (d.remoteId.str == id) return d;
    }
    return null;
  }

  Future<BluetoothCharacteristic?> _findRxChar(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final s in services) {
      if (s.uuid == serviceUuid) {
        for (final c in s.characteristics) {
          if (c.uuid == rxUuid) return c; // RX write
        }
      }
    }
    return null;
  }

  List<dynamic> _buildArrayPayload() {
    final p = sensors.selectedPlant;

    return [
      wifi.ssid.value,        // 0
      wifi.password.value,    // 1
      p.tempMin,              // 2
      p.tempMax,              // 3
      p.humMin,               // 4
      p.humMax,               // 5
      p.chlMin,               // 6
      p.chlMax,               // 7
    ];
  }


  // chunking per MTU (safe)
  Iterable<List<int>> _chunk(List<int> bytes, {int size = 180}) sync* {
    for (int i = 0; i < bytes.length; i += size) {
      final end = (i + size < bytes.length) ? i + size : bytes.length;
      yield bytes.sublist(i, end);
    }
  }

  Future<void> sendWifiAndSensorsTogether() async {
    final s = wifi.ssid.value.trim();
    final p = wifi.password.value;

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

      final rx = await _findRxChar(device);
      if (rx == null) {
        status.value = 'ERROR: RX characteristic non trovata (UUID?)';
        return;
      }

      final payloadStr = jsonEncode(_buildArrayPayload()); // JSON array
      final bytes = utf8.encode('$payloadStr\n');

      for (final part in _chunk(bytes)) {
        await rx.write(part, withoutResponse: false);
      }

      status.value = 'SENT';
    } catch (e) {
      status.value = 'ERROR: $e';
    }
  }
}
