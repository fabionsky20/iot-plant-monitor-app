import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/provision_controller.dart';
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


  @override
  void initState() {
    super.initState();
    controller = Get.find<ProvisionController>();
    controller.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7EE),
      appBar: AppBar(
        title: const Text('Associa ESP32'),
        actions: [
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
                  Center(child: Text('Nessun dispositivo trovato.\nTira giù per aggiornare.', textAlign: TextAlign.center)),
                ],
              );
            }

            final unique = <String, ScanResult>{};
            for (final r in results) {
              unique[r.device.remoteId.str] = r;
            }
            final list = unique.values.toList()
              ..sort((a, b) => b.rssi.compareTo(a.rssi)); // più vicino sopra

            final filtered = list.where((r) => r.rssi > -85).toList();

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = filtered[i];
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : 'Dispositivo sconosciuto';


                return Card(
                  child: ListTile(
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(r.device.remoteId.str),
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

                      // Dialog loading
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

                      // chiudi dialog
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
