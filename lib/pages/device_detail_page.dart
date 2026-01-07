import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/device_detail_controller.dart';
import '../controllers/mqtt_controller.dart';
import '../data/devices_repository.dart';
import '../data/history_repository.dart';
import '../data/plant_profiles.dart';
import '../models/sensor_sample.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F3E7),
              Color(0xFFF7FBF8),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<PlantProfile>(
            future: _resolvePlantProfile(deviceId),
            builder: (context, snap) {
              final profile = snap.data ?? PlantProfiles.all.firstWhere((p) => p.id == "basil");

              return Obx(() {
                final cur = ctrl.current.value;
                final history = ctrl.history.toList();

                final conn = _computeConnection(
                  backendConnected: mqtt.isConnected.value,
                  lastSampleTs: cur?.ts,
                );

                final alerts = _computeAlerts(history, profile);

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: _Header(
                          title: deviceName,
                          subtitle: "Profilo: ${profile.name}",
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ConnectionCard(
                          status: conn,
                          lastTs: cur?.ts,
                          lastError: mqtt.lastError.value,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _LastReadingCard(sample: cur),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ChartsCard(
                          isLoading: ctrl.isLoading.value,
                          history: history,
                          profile: profile,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _AlertsCard(alerts: alerts),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  /// Prova a leggere il profilo pianta dai device salvati (SharedPreferences).
  /// Cerchiamo chiavi comuni: profileId / plantProfileId / plantId / plantType.
  Future<PlantProfile> _resolvePlantProfile(String deviceId) async {
    final repo = DevicesRepository();
    final list = await repo.load();

    final d = list.cast<Map<String, dynamic>>().firstWhere(
          (e) => (e['deviceId']?.toString() ?? e['id']?.toString() ?? '') == deviceId,
      orElse: () => <String, dynamic>{},
    );

    final id = (d['profileId'] ??
        d['plantProfileId'] ??
        d['plantId'] ??
        d['plantType'])
        ?.toString();

    if (id != null) {
      final p = PlantProfiles.all.where((x) => x.id == id).toList();
      if (p.isNotEmpty) return p.first;
    }

    // fallback
    return PlantProfiles.all.firstWhere((p) => p.id == "basil");
  }
}

/// ---------- UI ----------

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(
          icon: Icons.spa,
          bg: Colors.white.withOpacity(0.85),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
            ),
          ]),
        )
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;

  const _RoundIcon({required this.icon, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Icon(icon, size: 22),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final _ConnStatus status;
  final DateTime? lastTs;
  final String? lastError;

  const _ConnectionCard({
    required this.status,
    required this.lastTs,
    required this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    final lastStr = lastTs == null ? '--' : DateFormat('dd/MM • HH:mm').format(lastTs!.toLocal());

    return _GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("Connessione con ESP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          _StatusPill(status: status),
        ]),
        const SizedBox(height: 10),
        Text("Ultimo pacchetto: $lastStr", style: TextStyle(color: Colors.black.withOpacity(0.65))),
        if (lastError != null) ...[
          const SizedBox(height: 8),
          Text(lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ]),
    );
  }
}

class _LastReadingCard extends StatelessWidget {
  final SensorSample? sample;
  const _LastReadingCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    final ts = sample?.ts;
    final tsStr = ts == null ? '--' : DateFormat('dd/MM • HH:mm').format(ts.toLocal());

    String fmtNum(num? v, {int digits = 1}) => v == null ? '--' : v.toStringAsFixed(digits);

    return _GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Ultimo dato ricevuto", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(tsStr, style: TextStyle(color: Colors.black.withOpacity(0.65))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.thermostat,
              label: "Temperatura",
              value: "${fmtNum(sample?.temperature)} °C",
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricTile(
              icon: Icons.water_drop,
              label: "Umidità",
              value: "${fmtNum(sample?.humidity)} %",
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _MetricTile(
          icon: Icons.eco,
          label: "Clorofilla",
          value: "${fmtNum(sample?.chlorophyll, digits: 2)} %",
          fullWidth: true,
        ),
      ]),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6))),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B8A3A), // verde acceso
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ChartsCard extends StatefulWidget {
  final bool isLoading;
  final List<SensorSample> history;
  final PlantProfile profile;

  const _ChartsCard({
    required this.isLoading,
    required this.history,
    required this.profile,
  });

  @override
  State<_ChartsCard> createState() => _ChartsCardState();
}

class _ChartsCardState extends State<_ChartsCard> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final data = _lastNHours(widget.history, 24);

    return _GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Andamento (ultime 24h)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(children: [
          _TabPill(text: "Temp", selected: tab == 0, onTap: () => setState(() => tab = 0)),
          const SizedBox(width: 8),
          _TabPill(text: "Umidità", selected: tab == 1, onTap: () => setState(() => tab = 1)),
          const SizedBox(width: 8),
          _TabPill(text: "Clorofilla", selected: tab == 2, onTap: () => setState(() => tab = 2)),
        ]),
        const SizedBox(height: 12),
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "Nessun dato nelle ultime 24 ore.",
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: _LineChart(
              samples: data,
              tab: tab,
              profile: widget.profile,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          "Note: il grafico va perfezionato",
          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
        ),
      ]),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<SensorSample> samples;
  final int tab; // 0 temp, 1 hum, 2 chl
  final PlantProfile profile;

  const _LineChart({
    required this.samples,
    required this.tab,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final start = samples.first.ts;
    double xOf(DateTime t) => t.difference(start).inMinutes.toDouble();

    double? yOf(SensorSample s) {
      if (tab == 0) return s.temperature;
      if (tab == 1) return s.humidity;
      return s.chlorophyll;
    }

    final okSpots = <FlSpot>[];
    final dangerSpots = <FlSpot>[];

    for (final s in samples) {
      final y = yOf(s);
      if (y == null) continue;
      final x = xOf(s.ts);

      final spot = FlSpot(x, y);
      if (_isOutOfRange(tab, y, profile)) {
        dangerSpots.add(spot);
      } else {
        okSpots.add(spot);
      }
    }


    final yVals = [...okSpots, ...dangerSpots].map((e) => e.y).toList();
    final rawMin = yVals.isEmpty ? 0.0 : yVals.reduce(math.min);
    final rawMax = yVals.isEmpty ? 1.0 : yVals.reduce(math.max);

    final range = (rawMax - rawMin).abs();
    final step = _niceStep(range);

    final minY = _floorTo(rawMin, step);
    final maxY = _ceilTo(rawMax, step);


    // X axis: label a ore intere
    String fmtHour(double minutes) {
      final t = start.add(Duration(minutes: minutes.round()));
      return DateFormat('HH').format(t);
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: step,
              getTitlesWidget: (value, meta) {
                // mostra solo multipli esatti dello step (evita numeri “strani”)
                final isMultiple = ((value - minY) / step).roundToDouble() == ((value - minY) / step);
                if (!isMultiple) return const SizedBox.shrink();

                final label = (step >= 1) ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          // PUNTI VERDI (OK)
          LineChartBarData(
            spots: okSpots,
            isCurved: false,
            barWidth: 0, // niente linea
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: const Color(0xFF1B8A3A), // verde acceso
                  strokeWidth: 0,
                );
              },
            ),
          ),

          // PUNTI ROSSI (FUORI SOGLIA)
          LineChartBarData(
            spots: dangerSpots,
            isCurved: false,
            barWidth: 0, // niente linea
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red,
                  strokeWidth: 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

double _niceStep(double range) {
  if (range <= 0) return 1;
  final rough = range / 4; // ~4 tick
  final pow10 = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final n = rough / pow10;

  double base;
  if (n <= 1) base = 1;
  else if (n <= 2) base = 2;
  else if (n <= 5) base = 5;
  else base = 10;

  return base * pow10;
}

double _floorTo(double v, double step) => (v / step).floorToDouble() * step;
double _ceilTo(double v, double step) => (v / step).ceilToDouble() * step;


/// ---------- Alerts / Status ----------

enum _ConnStatus { ok, warning, offline }

_ConnStatus _computeConnection({
  required bool backendConnected,
  required DateTime? lastSampleTs,
}) {
  if (!backendConnected) return _ConnStatus.offline;
  if (lastSampleTs == null) return _ConnStatus.warning;

  final age = DateTime.now().difference(lastSampleTs.toLocal());
  if (age.inHours < 12) return _ConnStatus.ok;
  if (age.inHours < 24) return _ConnStatus.warning;
  return _ConnStatus.offline;
}

class _StatusPill extends StatelessWidget {
  final _ConnStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      _ConnStatus.ok => "OK",
      _ConnStatus.warning => "ATTENZIONE",
      _ConnStatus.offline => "OFF",
    };

    final bg = switch (status) {
      _ConnStatus.ok => Colors.green.withOpacity(0.15),
      _ConnStatus.warning => Colors.orange.withOpacity(0.18),
      _ConnStatus.offline => Colors.red.withOpacity(0.15),
    };

    final fg = switch (status) {
      _ConnStatus.ok => Colors.green.shade900,
      _ConnStatus.warning => Colors.orange.shade900,
      _ConnStatus.offline => Colors.red.shade900,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
    );
  }
}

class _Alert {
  final String text;
  final DateTime ts;
  const _Alert({required this.text, required this.ts});
}

List<_Alert> _computeAlerts(List<SensorSample> history, PlantProfile p) {
  final data = _lastNHours(history, 24);
  final alerts = <_Alert>[];

  for (final s in data) {
    final t = s.temperature;
    final h = s.humidity;
    final c = s.chlorophyll;

    if (t != null && (t < p.tempMin || t > p.tempMax)) {
      alerts.add(_Alert(
        ts: s.ts,
        text:
        "Temperatura fuori soglia alle ${DateFormat('HH:mm').format(s.ts.toLocal())}: ${t.toStringAsFixed(1)} °C (min ${p.tempMin}, max ${p.tempMax})",
      ));
    }

    if (h != null && (h < p.humMin || h > p.humMax)) {
      alerts.add(_Alert(
        ts: s.ts,
        text:
        "Umidità fuori soglia alle ${DateFormat('HH:mm').format(s.ts.toLocal())}: ${h.toStringAsFixed(1)}% (min ${p.humMin}, max ${p.humMax})",
      ));
    }

    if (c != null && (c < p.chlMin || c > p.chlMax)) {
      alerts.add(_Alert(
        ts: s.ts,
        text:
        "Clorofilla fuori soglia alle ${DateFormat('HH:mm').format(s.ts.toLocal())}: ${c.toStringAsFixed(2)} (min ${p.chlMin}, max ${p.chlMax})",
      ));
    }
  }

  alerts.sort((a, b) => b.ts.compareTo(a.ts)); // più recenti prima
  return alerts;
}

bool _isOutOfRange(int tab, double v, PlantProfile p) {
  if (tab == 0) return v < p.tempMin || v > p.tempMax;
  if (tab == 1) return v < p.humMin || v > p.humMax;
  return v < p.chlMin || v > p.chlMax;
}

class _AlertsCard extends StatefulWidget {
  final List<_Alert> alerts;

  /// Quanti alert mostrare quando non è espanso
  final int previewCount;

  const _AlertsCard({
    required this.alerts,
    this.previewCount = 4,
  });

  @override
  State<_AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends State<_AlertsCard> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    // ✅ Filtra: ultimi 24h
    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 24));

    final recent = widget.alerts
        .where((a) => a.ts.isAfter(from))
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts)); // più recenti prima

    if (recent.isEmpty) return const SizedBox.shrink();

    final previewN = widget.previewCount.clamp(1, 20);
    final visible = showAll ? recent : recent.take(previewN).toList();
    final remaining = recent.length - visible.length;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Avvisi (ultime 24h)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (recent.length > previewN)
                TextButton(
                  onPressed: () => setState(() => showAll = !showAll),
                  child: Text(showAll ? "Nascondi" : "Mostra tutti"),
                ),
            ],
          ),

          const SizedBox(height: 6),

          ...visible.map((a) {
            final timeStr = DateFormat('HH:mm').format(a.ts.toLocal());
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "[$timeStr] ${a.text}",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (!showAll && remaining > 0)
            Text(
              "+ altri $remaining",
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }
}


/// Ultime N ore (se hai meno dati, torna quelli che ci sono)
List<SensorSample> _lastNHours(List<SensorSample> all, int hours) {
  if (all.isEmpty) return [];

  final now = DateTime.now();
  final from = now.subtract(Duration(hours: hours));

  final list = all.where((s) => s.ts.isAfter(from)).toList();
  list.sort((a, b) => a.ts.compareTo(b.ts));
  return list;
}
