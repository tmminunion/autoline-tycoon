import 'dart:math';
import 'package:flutter/material.dart';

class StationModel {
  final String id;
  final String code;
  final String name;
  final String role;
  final IconData icon;
  final Color accentColor;
  final double baseCycleSeconds;
  final double baseSpeedCost;
  final double baseBatchCost;

  int speedLevel;
  int batchLevel;
  double progress;
  int inputBuffer;
  bool isWorking;
  int activeBatch;

  StationModel({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    required this.icon,
    required this.accentColor,
    required this.baseCycleSeconds,
    required this.baseSpeedCost,
    required this.baseBatchCost,
    this.speedLevel = 1,
    this.batchLevel = 1,
    this.progress = 0.0,
    this.inputBuffer = 0,
    this.isWorking = false,
    this.activeBatch = 0,
  });

  double get cycleSeconds =>
      (baseCycleSeconds / (1.0 + (speedLevel - 1) * 0.22)).clamp(0.35, 60.0);

  int get batchSize => batchLevel;

  double get throughputPerMin => (60.0 / cycleSeconds) * batchSize;

  double get speedUpgradeCost =>
      (baseSpeedCost * pow(1.38, speedLevel - 1)).roundToDouble();

  double get batchUpgradeCost =>
      (baseBatchCost * pow(2.15, batchLevel - 1)).roundToDouble();

  Map<String, dynamic> toJson() => {
        'id': id,
        'speedLevel': speedLevel,
        'batchLevel': batchLevel,
        'inputBuffer': inputBuffer,
      };
}

class ProductTier {
  final String name;
  final String subtitle;
  final double unitValue;
  final double unlockCost;
  final Color color;
  final IconData icon;

  const ProductTier({
    required this.name,
    required this.subtitle,
    required this.unitValue,
    required this.unlockCost,
    required this.color,
    required this.icon,
  });
}

const List<ProductTier> kProductTiers = [
  ProductTier(
    name: 'Compact Car',
    subtitle: 'Entry city vehicle',
    unitValue: 25,
    unlockCost: 0,
    color: Color(0xFF00E5FF),
    icon: Icons.directions_car_filled_rounded,
  ),
  ProductTier(
    name: 'Urban Sedan',
    subtitle: 'Mid-tier commuter',
    unitValue: 75,
    unlockCost: 600,
    color: Color(0xFF29B6F6),
    icon: Icons.time_to_leave_rounded,
  ),
  ProductTier(
    name: 'Hybrid SUV',
    subtitle: 'High-margin family crossover',
    unitValue: 220,
    unlockCost: 3500,
    color: Color(0xFF00E676),
    icon: Icons.airport_shuttle_rounded,
  ),
  ProductTier(
    name: 'EV Sport GT',
    subtitle: 'Dual-motor electric coupe',
    unitValue: 680,
    unlockCost: 18000,
    color: Color(0xFFFFB300),
    icon: Icons.electric_car_rounded,
  ),
  ProductTier(
    name: 'Apex Hypercar',
    subtitle: 'Carbon-chassis flagship',
    unitValue: 2200,
    unlockCost: 95000,
    color: Color(0xFFFF7043),
    icon: Icons.speed_rounded,
  ),
  ProductTier(
    name: 'Cyber Mecha',
    subtitle: 'Autonomous titanium unit',
    unitValue: 7500,
    unlockCost: 480000,
    color: Color(0xFFD500F9),
    icon: Icons.precision_manufacturing_rounded,
  ),
];

String formatMoney(double value) {
  if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
  return '\$${value.toStringAsFixed(0)}';
}

String formatRate(double value) {
  if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M/s';
  if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(1)}K/s';
  return '\$${value.toStringAsFixed(1)}/s';
}

String formatCompactInt(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
