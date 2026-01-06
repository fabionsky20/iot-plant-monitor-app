import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/device_detail_controller.dart';
import '../controllers/mqtt_controller.dart';
import '../data/history_repository.dart';

class DeviceDetailPage extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const DeviceDetailPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    final mqtt = Get.find<MqttController>();

    final ctrl = Get.put(
      DeviceDetailController(
        deviceId: deviceId,
        history: HistoryRepository(),
        mqtt: mqtt,
      ),
      tag: deviceId,
    );

    return Scaffold(
      appBar: AppBar(title: Text(deviceName)),
      body: Obx(() {
        final cur = ctrl.current.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("Stato MQTT"),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(mqtt.isConnected.value ? "OK" : "OFF"),
                        ),
                      ],
                    ),
                    if (mqtt.lastError.value != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        mqtt.lastError.value!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text("Ultimo dato: ${cur?.ts.toLocal().toString() ?? '--'}"),
                    const SizedBox(height: 8),
                    Text("Temperatura: ${cur?.temperature?.toStringAsFixed(1) ?? '--'} °C"),
                    Text("Umidità: ${cur?.humidity?.toStringAsFixed(1) ?? '--'} %"),
                    Text("Clorofilla: ${cur?.chlorophyll?.toStringAsFixed(2) ?? '--'}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Obx(() {
              final alarm = ctrl.alarmText.value;
              if (alarm == null) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text("ALLARME"),
                  subtitle: Text(alarm),
                ),
              );
            }),

            const SizedBox(height: 16),

            if (ctrl.isLoading.value)
              const Center(child: CircularProgressIndicator())
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ctrl.history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = ctrl.history[i];
                    return ListTile(
                      title: Text(s.ts.toLocal().toString()),
                      subtitle: Text(
                        "T ${s.temperature?.toStringAsFixed(1) ?? '--'} °C | "
                            "H ${s.humidity?.toStringAsFixed(1) ?? '--'} % | "
                            "C ${s.chlorophyll?.toStringAsFixed(2) ?? '--'}",
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}
