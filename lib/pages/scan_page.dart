import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/BLE_controller.dart';
import '../controllers/devices_controller.dart';
import 'wifi_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final ProvisionController controller;

  bool _isConnecting = false;

  // ✅ di default nascondiamo i device senza nome
  bool _showUnknownDevices = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ProvisionController>();
    controller.startScan();
  }

  bool _hasName(ScanResult r) => r.device.platformName.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7EE),
      appBar: AppBar(
        title: const Text('Associa ESP32'),
        actions: [
          // ✅ toggle "occhio" per mostrare/nascondere sconosciuti
          IconButton(
            tooltip: _showUnknownDevices ? 'Nascondi sconosciuti' : 'Mostra sconosciuti',
            icon: Icon(_showUnknownDevices ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _showUnknownDevices = !_showUnknownDevices);
            },
          ),
          IconButton(
            tooltip: 'Riscansiona',
            onPressed: controller.startScan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => controller.startScan(),
        child: StreamBuilder<List<ScanResult>>(
          stream: controller.scanResults,
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];

            if (results.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Nessun dispositivo trovato.\nTira giù per aggiornare.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            // 1) dedup per remoteId
            final unique = <String, ScanResult>{};
            for (final r in results) {
              unique[r.device.remoteId.str] = r;
            }

            // 2) filtro distanza (RSSI)
            final list = unique.values.where((r) => r.rssi > -85).toList();

            // 3) separa known / unknown
            final known = <ScanResult>[];
            final unknown = <ScanResult>[];

            for (final r in list) {
              if (_hasName(r)) {
                known.add(r);
              } else {
                unknown.add(r);
              }
            }

            // 4) ordina per RSSI discendente
            known.sort((a, b) => b.rssi.compareTo(a.rssi));
            unknown.sort((a, b) => b.rssi.compareTo(a.rssi));

            // 5) se _showUnknownDevices = false, mostra solo known
            final displayList = _showUnknownDevices ? [...known, ...unknown] : known;

            if (displayList.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      _showUnknownDevices
                          ? 'Nessun dispositivo con RSSI > -85'
                          : 'Nessun dispositivo con nome trovato.\nPremi 👁 per mostrare anche gli sconosciuti.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: displayList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = displayList[i];

                final hasName = _hasName(r);
                final name = hasName ? r.device.platformName : 'Dispositivo sconosciuto';

                return Card(
                  child: ListTile(
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(r.device.remoteId.str),
                    leading: Icon(hasName ? Icons.memory : Icons.bluetooth_searching),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.black.withOpacity(0.06),
                      ),
                      child: Text('${r.rssi} dBm'),
                    ),
                    onTap: _isConnecting
                        ? null
                        : () async {
                      setState(() => _isConnecting = true);

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Expanded(child: Text('Connessione in corso...')),
                            ],
                          ),
                        ),
                      );

                      await controller.connectTo(r);

                      if (mounted) Navigator.pop(context);

                      setState(() => _isConnecting = false);

                      if (controller.connectionStateText.value == 'CONNECTED') {
                        final devicesC = Get.find<DevicesController>();
                        await devicesC.addOrUpdate(
                          alias: controller.deviceName.value,
                          deviceId: r.device.remoteId.str,
                        );

                        Get.off(() => const WifiPage());
                      } else {
                        Get.snackbar('Connessione', controller.connectionStateText.value);
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
