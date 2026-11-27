import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

class StationData {
  StationData({
    required this.id,
    required this.name,
    required this.role,
    required this.baseCycleSeconds,
    required this.baseUpgradeCost,
    required this.accentColor,
    required this.icon,
    this.level = 1,
    this.progress = 0.0,
    this.queue = 0,
  });

  final String id;
  final String name;
  final String role;
  final double baseCycleSeconds;
  final double baseUpgradeCost;
  final Color accentColor;
  final IconData icon;

  int level;
  double progress; // 0.0 to 1.0
  int queue; // Pending WIP parts from previous station

  /// Effective cycle duration in seconds (gets faster with level)
  double get cycleSeconds {
    final speedFactor = 1.0 + (level - 1) * 0.22;
    return max(0.25, baseCycleSeconds / speedFactor);
  }

  /// Throughput capacity in units per minute (excluding upstream starvation)
  double get unitsPerMinute => 60.0 / cycleSeconds;

  /// Cost to upgrade to next level
  double get upgradeCost => baseUpgradeCost * pow(1.22, level - 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'queue': queue,
      };
}

class GameState {
  GameState({
    required this.stations,
    this.cash = 25.0,
    this.lifetimeCash = 25.0,
    this.unitsProduced = 0,
    this.unitValueLevel = 1,
    this.batchLevel = 1,
    this.kaizenStars = 0,
  });

  final List<StationData> stations;
  double cash;
  double lifetimeCash;
  int unitsProduced;
  int unitValueLevel;
  int batchLevel;
  int kaizenStars;

  static List<StationData> createDefaultStations() => [
        StationData(
          id: 'stamping',
          name: 'Stamping Press',
          role: 'Pembentukan panel baja',
          baseCycleSeconds: 2.0,
          baseUpgradeCost: 15,
          accentColor: const Color(0xFF38BDF8),
          icon: Icons.precision_manufacturing,
        ),
        StationData(
          id: 'welding',
          name: 'Robotic Welding',
          role: 'Pengelasan titik rangka',
          baseCycleSeconds: 2.7,
          baseUpgradeCost: 55,
          accentColor: const Color(0xFFF59E0B),
          icon: Icons.bolt,
        ),
        StationData(
          id: 'assembly',
          name: 'Underbody Assembly',
          role: 'Perakitan komponen utama',
          baseCycleSeconds: 3.4,
          baseUpgradeCost: 180,
          accentColor: const Color(0xFFA855F7),
          icon: Icons.build_circle,
        ),
        StationData(
          id: 'qc',
          name: 'Quality Control',
          role: 'Inspeksi akhir & kirim',
          baseCycleSeconds: 4.0,
          baseUpgradeCost: 520,
          accentColor: const Color(0xFF10B981),
          icon: Icons.verified,
        ),
      ];

  factory GameState.initial() => GameState(stations: createDefaultStations());

  /// Global multiplier from Prestige Kaizen Stars (+50% per star)
  double get prestigeMultiplier => 1.0 + (kaizenStars * 0.5);

  /// Units produced per finished cycle
  int get batchSize => batchLevel;

  /// Cash earned per completed finished unit
  double get unitPrice {
    final totalStationLevels = stations.fold<int>(0, (sum, s) => sum + s.level);
    final base = 6.0 * pow(1.35, unitValueLevel - 1);
    final qualityBonus = 1.0 + (totalStationLevels - stations.length) * 0.04;
    return base * qualityBonus * prestigeMultiplier;
  }

  /// Global Upgrade costs
  double get unitValueUpgradeCost => 120.0 * pow(1.65, unitValueLevel - 1);
  double get batchUpgradeCost => 650.0 * pow(2.8, batchLevel - 1);

  /// Bottleneck index (station with lowest unitsPerMinute)
  int get bottleneckIndex {
    var minIdx = 0;
    var minRate = stations[0].unitsPerMinute;
    for (var i = 1; i < stations.length; i++) {
      if (stations[i].unitsPerMinute < minRate) {
        minRate = stations[i].unitsPerMinute;
        minIdx = i;
      }
    }
    return minIdx;
  }

  /// Effective line throughput in units per minute (governed by bottleneck)
  double get effectiveUnitsPerMinute =>
      stations[bottleneckIndex].unitsPerMinute * batchSize;

  /// Effective cash income per second
  double get incomePerSecond => (effectiveUnitsPerMinute / 60.0) * unitPrice;

  /// Prestige calculation (unlocks at $50,000 lifetime earnings)
  static const double prestigeThreshold = 50000.0;

  int get claimableKaizenStars {
    if (lifetimeCash < prestigeThreshold) return 0;
    final totalPotential = sqrt(lifetimeCash / prestigeThreshold).floor();
    return max(0, totalPotential - kaizenStars);
  }

  /// Advance simulation by [dtSeconds]
  /// Returns cash earned in this tick
  double tick(double dtSeconds) {
    double earned = 0.0;

    for (var i = 0; i < stations.length; i++) {
      final station = stations[i];
      final hasInput = i == 0 || station.queue > 0;

      if (!hasInput) {
        continue;
      }

      station.progress += dtSeconds / station.cycleSeconds;
      while (station.progress >= 1.0) {
        if (i > 0 && station.queue <= 0) {
          station.progress = 0.0;
          break;
        }
        station.progress -= 1.0;
        if (i > 0) {
          station.queue -= 1;
        }

        if (i < stations.length - 1) {
          // Pass batch to next station's WIP buffer (capped to prevent overflow)
          final next = stations[i + 1];
          if (next.queue < 999) {
            next.queue += 1;
          }
        } else {
          // Finished product!
          final produced = batchSize;
          unitsProduced += produced;
          final reward = produced * unitPrice;
          cash += reward;
          lifetimeCash += reward;
          earned += reward;
        }
      }
    }

    return earned;
  }

  /// Manual tap boost on a station
  bool boostStation(int index) {
    if (index < 0 || index >= stations.length) return false;
    final station = stations[index];
    if (index > 0 && station.queue <= 0) return false;
    station.progress += 0.28;
    return true;
  }

  bool upgradeStation(int index) {
    final station = stations[index];
    final cost = station.upgradeCost;
    if (cash < cost) return false;
    cash -= cost;
    station.level += 1;
    return true;
  }

  bool upgradeUnitValue() {
    final cost = unitValueUpgradeCost;
    if (cash < cost) return false;
    cash -= cost;
    unitValueLevel += 1;
    return true;
  }

  bool upgradeBatchSize() {
    final cost = batchUpgradeCost;
    if (cash < cost) return false;
    cash -= cost;
    batchLevel += 1;
    return true;
  }

  bool prestigeReset() {
    final gain = claimableKaizenStars;
    if (gain <= 0) return false;
    kaizenStars += gain;
    cash = 25.0;
    unitValueLevel = 1;
    batchLevel = 1;
    for (final s in stations) {
      s.level = 1;
      s.progress = 0.0;
      s.queue = 0;
    }
    return true;
  }

  String toJsonString() {
    return jsonEncode({
      'cash': cash,
      'lifetimeCash': lifetimeCash,
      'unitsProduced': unitsProduced,
      'unitValueLevel': unitValueLevel,
      'batchLevel': batchLevel,
      'kaizenStars': kaizenStars,
      'stations': stations.map((s) => s.toJson()).toList(),
    });
  }

  static GameState fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final stations = createDefaultStations();
    final savedStations = (map['stations'] as List<dynamic>?) ?? [];
    for (final item in savedStations) {
      final m = item as Map<String, dynamic>;
      final idx = stations.indexWhere((s) => s.id == m['id']);
      if (idx != -1) {
        stations[idx].level = (m['level'] as num?)?.toInt() ?? 1;
        stations[idx].queue = (m['queue'] as num?)?.toInt() ?? 0;
      }
    }
    return GameState(
      stations: stations,
      cash: (map['cash'] as num?)?.toDouble() ?? 25.0,
      lifetimeCash: (map['lifetimeCash'] as num?)?.toDouble() ?? 25.0,
      unitsProduced: (map['unitsProduced'] as num?)?.toInt() ?? 0,
      unitValueLevel: (map['unitValueLevel'] as num?)?.toInt() ?? 1,
      batchLevel: (map['batchLevel'] as num?)?.toInt() ?? 1,
      kaizenStars: (map['kaizenStars'] as num?)?.toInt() ?? 0,
    );
  }
}
