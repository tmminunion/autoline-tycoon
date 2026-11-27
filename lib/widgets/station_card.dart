import 'package:flutter/material.dart';

import '../models/game_models.dart';

class StationCard extends StatelessWidget {
  final StationModel station;
  final int index;
  final bool isBottleneck;
  final bool isTurbo;
  final double cash;
  final VoidCallback onTapBoost;
  final VoidCallback onUpgradeSpeed;
  final VoidCallback onUpgradeBatch;

  const StationCard({
    super.key,
    required this.station,
    required this.index,
    required this.isBottleneck,
    required this.isTurbo,
    required this.cash,
    required this.onTapBoost,
    required this.onUpgradeSpeed,
    required this.onUpgradeBatch,
  });

  @override
  Widget build(BuildContext context) {
    final canAffordSpeed = cash >= station.speedUpgradeCost;
    final canAffordBatch = cash >= station.batchUpgradeCost;
    final isStarving = index > 0 && !station.isWorking && station.inputBuffer == 0;

    final borderColor = isBottleneck
        ? const Color(0xFFFF5252).withAlpha(170)
        : station.accentColor.withAlpha(90);

    return GestureDetector(
      onTap: onTapBoost,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131B31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isBottleneck ? 1.5 : 1.0),
          boxShadow: [
            BoxShadow(
              color: station.accentColor.withAlpha(20),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: station.accentColor.withAlpha(32),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: station.accentColor.withAlpha(110)),
                  ),
                  child: Icon(station.icon, color: station.accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: station.accentColor.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              station.code,
                              style: TextStyle(
                                color: station.accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              station.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        station.role,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(isStarving),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar & telemetry
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cycle: ${station.cycleSeconds.toStringAsFixed(2)}s  |  ${station.throughputPerMin.toStringAsFixed(1)} u/min',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (index > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: station.inputBuffer > 0
                          ? const Color(0xFF00E5FF).withAlpha(28)
                          : const Color(0xFF334155).withAlpha(120),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'WIP: ${station.inputBuffer}',
                      style: TextStyle(
                        color: station.inputBuffer > 0
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Text(
                    'RAW: INF',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: station.progress.clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isTurbo ? const Color(0xFFFFB300) : station.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tap card to +25% boost',
                  style: TextStyle(
                    color: station.accentColor.withAlpha(180),
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'SPD Lv.${station.speedLevel}  •  BATCH x${station.batchSize}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Upgrade buttons
            Row(
              children: [
                Expanded(
                  child: _UpgradeButton(
                    label: 'Speed Lv.${station.speedLevel + 1}',
                    costText: formatMoney(station.speedUpgradeCost),
                    icon: Icons.bolt_rounded,
                    enabled: canAffordSpeed,
                    accentColor: station.accentColor,
                    onPressed: onUpgradeSpeed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _UpgradeButton(
                    label: 'Batch x${station.batchLevel + 1}',
                    costText: formatMoney(station.batchUpgradeCost),
                    icon: Icons.layers_rounded,
                    enabled: canAffordBatch,
                    accentColor: const Color(0xFF00E676),
                    onPressed: onUpgradeBatch,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isStarving) {
    String label;
    Color color;

    if (isBottleneck) {
      label = 'BOTTLENECK';
      color = const Color(0xFFFF5252);
    } else if (isStarving) {
      label = 'WAIT WIP';
      color = const Color(0xFFFFB300);
    } else if (isTurbo) {
      label = 'TURBO 2X';
      color = const Color(0xFFFFB300);
    } else {
      label = 'RUNNING';
      color = const Color(0xFF00E676);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(130)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final String label;
  final String costText;
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback onPressed;

  const _UpgradeButton({
    required this.label,
    required this.costText,
    required this.icon,
    required this.enabled,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? accentColor.withAlpha(35)
          : const Color(0xFF1E293B).withAlpha(160),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? accentColor.withAlpha(150)
                  : const Color(0xFF334155),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? accentColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? Colors.white : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      costText,
                      style: TextStyle(
                        color: enabled ? accentColor : const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
