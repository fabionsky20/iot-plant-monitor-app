import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ProvisionController extends GetxController {
  // Stato minimo
  final deviceName = ''.obs;  //nome del device
  final connectedDeviceId = ''.obs;  //id device
  final connectionStateText = 'DISCONNECTED'.obs;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;  //risultati dello sca BLE

  Future<bool> _ensurePermissions() async { //ricerca dei permessi
    if (!Platform.isAndroid) return true;

    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();

    // Spesso richiesto per visualizzare risultati scan su molti device
    final loc = await Permission.locationWhenInUse.request();

    return scan.isGranted && connect.isGranted; // location la lasciamo “soft”
  }

  Future<void> startScan() async {  //start scan
    final ok = await _ensurePermissions();
    if (!ok) return;

    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  Future<void> connectTo(ScanResult r) async {
    // stop scan prima di connettere
    await FlutterBluePlus.stopScan();

    connectionStateText.value = 'CONNECTING...';

    try {
      await r.device.connect(timeout: const Duration(seconds: 12), autoConnect: false);

      connectedDeviceId.value = r.device.remoteId.str;
      connectionStateText.value = 'CONNECTED';

      // Se vuoi: ascolta disconnessione
      r.device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          connectionStateText.value = 'DISCONNECTED';
          connectedDeviceId.value = '';
        }
      });
    } catch (e) {
      // Se era già connesso o errore: prova a leggere stato
      connectionStateText.value = 'ERROR: $e';
    }
  }

  void setAliasName(String name) {
    deviceName.value = name.trim();
  }

  Future<void> disconnect() async {
    try {
      // Non abbiamo l’istanza del device salvata: in questo step minimale
      // non disconnettiamo manualmente. Lo faremo quando gestiremo lista devices.
      connectionStateText.value = 'DISCONNECTED';
      connectedDeviceId.value = '';
    } catch (_) {}
  }
}
