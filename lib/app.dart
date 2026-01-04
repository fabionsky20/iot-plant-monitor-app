import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/provision_controller.dart';
import 'controllers/devices_controller.dart';
import 'pages/home_page.dart';

class PlantFormioApp extends StatelessWidget {
  const PlantFormioApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ProvisionController(), permanent: true);
    Get.put(DevicesController(), permanent: true);

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PlantFormio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const HomePage(),
    );
  }
}
