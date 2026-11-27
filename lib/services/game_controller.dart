import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_models.dart';

class GameController extends ChangeNotifier {
  static const String _saveKey = 'autoline_tycoon_save_v1';
  static const int _maxOfflineSeconds = 8 * 3600; // 8 hours cap

  double cash = 50.0;
  int totalUnitsShipped = 0;
  int productTierIndex = 0;

  double turboRemainingSeconds = 0.0;
  double turboCooldownSeconds = 0.0;

  double pendingOfflineEarnings = 0.0;
  int pendingOfflineSeconds = 0;

  late List<StationModel> stations;

  Timer? _tickTimer;
  Timer? _autoSaveTimer;
  bool _initialized = false;

  GameController() {
    stations = _createDefaultStations();
  }

  bool get isInitialized => _initialized;
  bool get isTurboActive => turboRemainingSeconds > 0;
  bool get canActivateTurbo =>
      turboRemainingSeconds <= 0 && turboCooldownSeconds <= 0;

  ProductTier get currentProduct => kProductTiers[productTierIndex];

  ProductTier? get nextProduct =>
      productTierIndex + 1 < kProductTiers.length
          ? kProductTiers[productTierIndex + 1]
          : null;

  double get speedMultiplier => isTurboActive ? 2.0 : 1.0;

  int get bottleneckIndex {
    int idx = 0;
    double lowest = stations[0].throughputPerMin;
    for (int i = 1; i < stations.length; i++) {
      if (stations[i].throughputPerMin < lowest) {
        lowest = stations[i].throughputPerMin;
        idx = i;
      }
    }
    return idx;
  }

  double get lineThroughputPerMin {
    double lowest = stations[0].throughputPerMin;
    for (final s in stations) {
      if (s.throughputPerMin < lowest) {
        lowest = s.throughputPerMin;
      }
    }
    return lowest * speedMultiplier;
  }

  double get estimatedUnitsPerHour => lineThroughputPerMin * 60.0;

  double get estimatedCashPerSec =>
      (lineThroughputPerMin / 60.0) * currentProduct.unitValue;

  List<StationModel> _createDefaultStations() {
    return [
      StationModel(
        id: 'stamping',
        code: 'ST-01',
        name: 'Stamping Press',
        role: 'Raw steel -> Body panels',
        icon: Icons.compress_rounded,
        accentColor: const Color(0xFF00E5FF),
        baseCycleSeconds: 2.2,
        baseSpeedCost: 30,
        baseBatchCost: 140,
      ),
      StationModel(
        id: 'welding',
        code: 'ST-02',
        name: 'Robotic Welding',
        role: 'Panels -> Underbody chassis',
        icon: Icons.precision_manufacturing_rounded,
        accentColor: const Color(0xFFFFB300),
        baseCycleSeconds: 3.0,
        baseSpeedCost: 55,
        baseBatchCost: 240,
      ),
      StationModel(
        id: 'assembly',
        code: 'ST-03',
        name: 'Final Assembly',
        role: 'Chassis -> Complete unit',
        icon: Icons.build_circle_rounded,
        accentColor: const Color(0xFF7C4DFF),
        baseCycleSeconds: 3.6,
        baseSpeedCost: 90,
        baseBatchCost: 420,
      ),
      StationModel(
        id: 'qc',
        code: 'ST-04',
        name: 'Quality Check & Ship',
        role: 'Inspect -> Deliver & Earn',
        icon: Icons.verified_rounded,
        accentColor: const Color(0xFF00E676),
        baseCycleSeconds: 2.6,
        baseSpeedCost: 120,
        baseBatchCost: 550,
      ),
    ];
  }

  Future<void> init() async {
    if (_initialized) return;
    await loadGame();
    _initialized = true;

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tick(0.1),
    );

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => saveGame(),
    );

    notifyListeners();
  }

  void _tick(double dt) {
    if (turboRemainingSeconds > 0) {
      turboRemainingSeconds = max(0.0, turboRemainingSeconds - dt);
      if (turboRemainingSeconds == 0) {
        turboCooldownSeconds = 45.0;
      }
    } else if (turboCooldownSeconds > 0) {
      turboCooldownSeconds = max(0.0, turboCooldownSeconds - dt);
    }

    final mult = speedMultiplier;

    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];

      if (!station.isWorking) {
        if (i == 0) {
          station.isWorking = true;
          station.activeBatch = station.batchSize;
        } else if (station.inputBuffer > 0) {
          final take = min(station.batchSize, station.inputBuffer);
          station.inputBuffer -= take;
          station.activeBatch = take;
          station.isWorking = true;
        }
      }

      if (station.isWorking) {
        station.progress += (dt * mult) / station.cycleSeconds;
        if (station.progress >= 1.0) {
          _completeStationCycle(i);
        }
      }
    }

    notifyListeners();
  }

  void _completeStationCycle(int index) {
    final station = stations[index];
    final produced = max(1, station.activeBatch);
    station.progress = 0.0;
    station.isWorking = false;
    station.activeBatch = 0;

    if (index < stations.length - 1) {
      stations[index + 1].inputBuffer += produced;
    } else {
      totalUnitsShipped += produced;
      cash += produced * currentProduct.unitValue;
    }
  }

  void tapBoostStation(int index) {
    if (index < 0 || index >= stations.length) return;
    final station = stations[index];

    if (!station.isWorking) {
      if (index == 0) {
        station.isWorking = true;
        station.activeBatch = station.batchSize;
      } else if (station.inputBuffer > 0) {
        final take = min(station.batchSize, station.inputBuffer);
        station.inputBuffer -= take;
        station.activeBatch = take;
        station.isWorking = true;
      } else {
        return;
      }
    }

    station.progress += 0.25;
    if (station.progress >= 1.0) {
      _completeStationCycle(index);
    }
    notifyListeners();
  }

  bool upgradeSpeed(int index) {
    final station = stations[index];
    final cost = station.speedUpgradeCost;
    if (cash < cost) return false;

    cash -= cost;
    station.speedLevel += 1;
    notifyListeners();
    saveGame();
    return true;
  }

  bool upgradeBatch(int index) {
    final station = stations[index];
    final cost = station.batchUpgradeCost;
    if (cash < cost) return false;

    cash -= cost;
    station.batchLevel += 1;
    notifyListeners();
    saveGame();
    return true;
  }

  bool upgradeProductTier() {
    final next = nextProduct;
    if (next == null || cash < next.unlockCost) return false;

    cash -= next.unlockCost;
    productTierIndex += 1;
    notifyListeners();
    saveGame();
    return true;
  }

  void activateTurbo() {
    if (!canActivateTurbo) return;
    turboRemainingSeconds = 30.0;
    notifyListeners();
  }

  void claimOfflineEarnings() {
    if (pendingOfflineEarnings > 0) {
      cash += pendingOfflineEarnings;
      final units = (pendingOfflineEarnings / currentProduct.unitValue).floor();
      totalUnitsShipped += units;
    }
    pendingOfflineEarnings = 0.0;
    pendingOfflineSeconds = 0;
    notifyListeners();
    saveGame();
  }

  Future<void> saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'cash': cash,
        'totalUnitsShipped': totalUnitsShipped,
        'productTierIndex': productTierIndex,
        'savedAtMs': DateTime.now().millisecondsSinceEpoch,
        'stations': stations.map((s) => s.toJson()).toList(),
      };
      await prefs.setString(_saveKey, jsonEncode(payload));
    } catch (_) {
      // Ignore storage errors gracefully
    }
  }

  Future<void> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      cash = (data['cash'] as num?)?.toDouble() ?? 50.0;
      totalUnitsShipped = (data['totalUnitsShipped'] as num?)?.toInt() ?? 0;
      final savedTier = (data['productTierIndex'] as num?)?.toInt() ?? 0;
      productTierIndex = savedTier.clamp(0, kProductTiers.length - 1);

      final savedStations = data['stations'] as List<dynamic>?;
      if (savedStations != null) {
        for (final item in savedStations) {
          final map = item as Map<String, dynamic>;
          final id = map['id'] as String?;
          final match = stations.where((s) => s.id == id);
          if (match.isNotEmpty) {
            final target = match.first;
            target.speedLevel = max(1, (map['speedLevel'] as num?)?.toInt() ?? 1);
            target.batchLevel = max(1, (map['batchLevel'] as num?)?.toInt() ?? 1);
            target.inputBuffer = max(0, (map['inputBuffer'] as num?)?.toInt() ?? 0);
          }
        }
      }

      final savedAtMs = (data['savedAtMs'] as num?)?.toInt();
      if (savedAtMs != null) {
        final elapsedSec =
            ((DateTime.now().millisecondsSinceEpoch - savedAtMs) / 1000)
                .floor()
                .clamp(0, _maxOfflineSeconds);
        if (elapsedSec >= 30) {
          // Offline efficiency = 65% of normal steady-state rate
          final earned =
              (lineThroughputPerMin / 60.0) * currentProduct.unitValue * elapsedSec * 0.65;
          if (earned >= 1.0) {
            pendingOfflineSeconds = elapsedSec;
            pendingOfflineEarnings = earned;
          }
        }
      }
    } catch (_) {
      // Fallback to default state if corrupted
    }
  }

  Future<void> resetGame() async {
    cash = 50.0;
    totalUnitsShipped = 0;
    productTierIndex = 0;
    turboRemainingSeconds = 0.0;
    turboCooldownSeconds = 0.0;
    pendingOfflineEarnings = 0.0;
    pendingOfflineSeconds = 0;
    stations = _createDefaultStations();
    notifyListeners();
    await saveGame();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _autoSaveTimer?.cancel();
    saveGame();
    super.dispose();
  }
}
