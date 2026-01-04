import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wifi_provision_controller.dart';
import '../controllers/sensors_provision_controller.dart';
import '../controllers/provision_payload_controller.dart';
import '../data/plant_profiles.dart';
import 'home_page.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final wifiC = Get.put(WifiProvisionController());
    final sensorsC = Get.put(SensorsProvisionController());
    final payloadC = Get.put(ProvisionPayloadController());

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Configura Wi-Fi e pianta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rete Wi-Fi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nome rete (SSID)',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onChanged: wifiC.setSsid,
              ),
              const SizedBox(height: 12),

              TextField(
                decoration: InputDecoration(
                  labelText: 'Password Wi-Fi',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Nascondi' : 'Mostra',
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                obscureText: !_showPassword,
                onChanged: wifiC.setPassword,
              ),

              const SizedBox(height: 18),
              const Divider(height: 30),

              const Text('Tipo di pianta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              Obx(() {
                return DropdownButtonFormField<String>(
                  value: sensorsC.selectedPlantId.value,
                  decoration: const InputDecoration(
                    labelText: 'Seleziona pianta',
                    prefixIcon: Icon(Icons.spa_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: PlantProfiles.all
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) sensorsC.setPlant(v);
                  },
                );
              }),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: () async {
                  await payloadC.sendWifiAndSensorsTogether();

                  if (payloadC.status.value == 'SENT') {
                    Get.offAll(() => const HomePage());
                    Get.snackbar('Configurazione inviata', 'Dati inviati a ESP32 ✅');
                  } else if (payloadC.status.value.startsWith('ERROR')) {
                    Get.snackbar('Errore', payloadC.status.value);
                  } else {
                    Get.snackbar('Stato', payloadC.status.value);
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Invia configurazione a ESP32'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),

              const SizedBox(height: 12),
              Obx(() => Text('Stato: ${payloadC.status.value}', textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
