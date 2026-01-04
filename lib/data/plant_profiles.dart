class PlantProfile {
  final String id;
  final String name;

  final double tempMin, tempMax; // °C
  final double humMin, humMax;   // %
  final double chlMin, chlMax;   // %

  const PlantProfile({
    required this.id,
    required this.name,
    required this.tempMin,
    required this.tempMax,
    required this.humMin,
    required this.humMax,
    required this.chlMin,
    required this.chlMax,
  });

  Map<String, dynamic> thresholdsJson() => {
    "temperature": {"min": tempMin, "max": tempMax},
    "humidity": {"min": humMin, "max": humMax},
    "chlorophyll": {"min": chlMin, "max": chlMax},
  };
}

class PlantProfiles {
  static const all = <PlantProfile>[
    PlantProfile(id: "rosemary", name: "Rosmarino", tempMin: 8, tempMax: 32, humMin: 35, humMax: 65, chlMin: 20, chlMax: 80),
    PlantProfile(id: "basil", name: "Basilico", tempMin: 15, tempMax: 30, humMin: 45, humMax: 75, chlMin: 25, chlMax: 85),
    PlantProfile(id: "mint", name: "Menta", tempMin: 10, tempMax: 28, humMin: 50, humMax: 85, chlMin: 25, chlMax: 85),
    PlantProfile(id: "thyme", name: "Timo", tempMin: 6, tempMax: 30, humMin: 30, humMax: 60, chlMin: 20, chlMax: 80),
    PlantProfile(id: "sage", name: "Salvia", tempMin: 6, tempMax: 30, humMin: 30, humMax: 60, chlMin: 20, chlMax: 80),

    PlantProfile(id: "lavender", name: "Lavanda", tempMin: 5, tempMax: 32, humMin: 25, humMax: 55, chlMin: 20, chlMax: 75),
    PlantProfile(id: "aloe", name: "Aloe", tempMin: 12, tempMax: 35, humMin: 15, humMax: 45, chlMin: 15, chlMax: 70),
    PlantProfile(id: "cactus", name: "Cactus", tempMin: 10, tempMax: 40, humMin: 10, humMax: 35, chlMin: 10, chlMax: 60),

    PlantProfile(id: "tomato", name: "Pomodoro", tempMin: 12, tempMax: 32, humMin: 50, humMax: 80, chlMin: 25, chlMax: 90),
    PlantProfile(id: "strawberry", name: "Fragola", tempMin: 10, tempMax: 28, humMin: 55, humMax: 85, chlMin: 25, chlMax: 90),
    PlantProfile(id: "pepper", name: "Peperone", tempMin: 14, tempMax: 32, humMin: 45, humMax: 75, chlMin: 25, chlMax: 90),

    PlantProfile(id: "orchid", name: "Orchidea", tempMin: 16, tempMax: 28, humMin: 55, humMax: 85, chlMin: 20, chlMax: 85),
    PlantProfile(id: "fern", name: "Felce", tempMin: 14, tempMax: 26, humMin: 60, humMax: 90, chlMin: 20, chlMax: 85),
    PlantProfile(id: "monstera", name: "Monstera", tempMin: 16, tempMax: 30, humMin: 50, humMax: 80, chlMin: 20, chlMax: 85),
    PlantProfile(id: "pothos", name: "Pothos", tempMin: 15, tempMax: 30, humMin: 45, humMax: 75, chlMin: 20, chlMax: 85),

    PlantProfile(id: "lemon", name: "Limone", tempMin: 8, tempMax: 34, humMin: 40, humMax: 70, chlMin: 20, chlMax: 85),
    PlantProfile(id: "olive", name: "Olivo", tempMin: 5, tempMax: 35, humMin: 25, humMax: 55, chlMin: 20, chlMax: 80),
    PlantProfile(id: "bamboo", name: "Bambù", tempMin: 12, tempMax: 30, humMin: 55, humMax: 90, chlMin: 20, chlMax: 85),

    PlantProfile(id: "cyclamen", name: "Ciclamino", tempMin: 8, tempMax: 22, humMin: 45, humMax: 75, chlMin: 20, chlMax: 80),
    PlantProfile(id: "geranium", name: "Geranio", tempMin: 10, tempMax: 30, humMin: 35, humMax: 65, chlMin: 20, chlMax: 80),
  ];
}