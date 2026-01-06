class SensorSample {
  final String deviceId;
  final DateTime ts;
  final double? temperature;
  final double? humidity;
  final double? chlorophyll;

  const SensorSample({
    required this.deviceId,
    required this.ts,
    this.temperature,
    this.humidity,
    this.chlorophyll,
  });
}
