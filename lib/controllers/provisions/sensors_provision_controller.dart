import 'package:get/get.dart';
import '../../data/plant_profiles.dart';

class SensorsProvisionController extends GetxController {
  // quale pianta è selezionata
  final selectedPlantId = PlantProfiles.all.first.id.obs;

  void setPlant(String plantId) => selectedPlantId.value = plantId;

  PlantProfile get selectedPlant =>
      PlantProfiles.all.firstWhere((p) => p.id == selectedPlantId.value);

  // solo la parte soglie da includere nel payload totale
  Map<String, dynamic> buildSensorsPayload() {
    final p = selectedPlant;
    return {
      "plant": {"id": p.id, "name": p.name},
      "thresholds": p.thresholdsJson(),
    };
  }
}
