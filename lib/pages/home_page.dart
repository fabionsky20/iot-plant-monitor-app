import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/provision_controller.dart';
import '../controllers/devices_controller.dart';
import 'scan_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _addDeviceFlow(BuildContext context) async {
    final ble = Get.find<ProvisionController>();
    final nameController = TextEditingController(text: ble.deviceName.value);

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nome dispositivo'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Es. Basilico balcone',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Continua'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    ble.setAliasName(name);
    Get.to(() => const ScanPage());
  }

  Future<void> _renameDeviceDialog(BuildContext context, DevicesController devicesC, SavedDevice d) async {
    final c = TextEditingController(text: d.alias);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica nome'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;
    await devicesC.renameDevice(d.deviceId, newName);
  }

  Future<void> _confirmDelete(BuildContext context, DevicesController devicesC, SavedDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare dispositivo?'),
        content: Text('Vuoi eliminare "${d.alias}" dalla lista?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await devicesC.deleteById(d.deviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesC = Get.find<DevicesController>();
    final ble = Get.find<ProvisionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantFormio'),
        actions: [
          IconButton(
            tooltip: 'Ricarica',
            onPressed: devicesC.loadDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                title: Text('Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profilo'),
                onTap: () {
                  Navigator.pop(context);
                  Get.snackbar('Info', 'Profilo: da fare');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Impostazioni'),
                onTap: () {
                  Navigator.pop(context);
                  Get.snackbar('Info', 'Impostazioni: da fare');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Info app'),
                onTap: () {
                  Navigator.pop(context);
                  Get.snackbar('Info', 'PlantFormio: BLE provisioning');
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDeviceFlow(context),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: Container(
        color: const Color(0xFFEAF7EE),
          child: Obx(() {
            final list = devicesC.devices;
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.spa_outlined, size: 60),
                      SizedBox(height: 12),
                      Text('Nessun dispositivo ancora'),
                      SizedBox(height: 6),
                      Text('Premi "Aggiungi" per configurare il tuo ESP32',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = list[i];
                final isConnected = (ble.connectedDeviceId.value == d.deviceId);

                return Card(
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      child: Icon(
                          isConnected ? Icons.bluetooth_connected : Icons
                              .sensors),
                    ),
                    title: Text(d.alias,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      isConnected ? 'Connesso' : 'Non connesso',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Modifica',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _renameDeviceDialog(context, devicesC, d),
                        ),
                        IconButton(
                          tooltip: 'Elimina',
                          icon: const Icon(
                              Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(context, devicesC, d),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        ),
      )
    );
  }
}
