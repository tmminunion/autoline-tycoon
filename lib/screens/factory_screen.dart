import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../services/game_controller.dart';
import '../widgets/station_card.dart';

class FactoryScreen extends StatefulWidget {
  const FactoryScreen({super.key});

  @override
  State<FactoryScreen> createState() => _FactoryScreenState();
}

class _FactoryScreenState extends State<FactoryScreen>
    with WidgetsBindingObserver {
  final GameController _controller = GameController();
  bool _offlineDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onGameUpdated);
    _controller.init().then((_) {
      if (mounted &&
          !_offlineDialogShown &&
          _controller.pendingOfflineEarnings > 0) {
        _offlineDialogShown = true;
        _showOfflineDialog();
      }
    });
  }

  void _onGameUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _controller.saveGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onGameUpdated);
    _controller.dispose();
    super.dispose();
  }

  void _showOfflineDialog() {
    final mins = (_controller.pendingOfflineSeconds / 60).floor();
    final earned = formatMoney(_controller.pendingOfflineEarnings);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.nights_stay_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 10),
            Text(
              'Offline Production',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pabrik tetap beroperasi selama $mins menit saat kamu offline.',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withAlpha(25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E676).withAlpha(110)),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL PENDAPATAN OFFLINE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+$earned',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF090D1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _controller.claimOfflineEarnings();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Klaim Sekarang',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B31),
        title: const Text(
          'Reset Progres Pabrik?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Semua uang, level mesin, dan tier produk akan kembali ke awal.',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            onPressed: () {
              _controller.resetGame();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottleneckIdx = _controller.bottleneckIndex;
    final product = _controller.currentProduct;
    final nextProd = _controller.nextProduct;

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1426),
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.factory_rounded,
              color: Color(0xFF00E5FF),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'AUTOLINE TYCOON',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Progress',
            onPressed: _confirmReset,
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
      body: !_controller.isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                children: [
                  _buildKpiHeader(),
                  const SizedBox(height: 12),
                  _buildProductTierCard(product, nextProd),
                  const SizedBox(height: 12),
                  _buildTurboBar(),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'PRODUCTION LINE STATIONS',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (int i = 0; i < _controller.stations.length; i++) ...[
                    StationCard(
                      station: _controller.stations[i],
                      index: i,
                      isBottleneck: i == bottleneckIdx,
                      isTurbo: _controller.isTurboActive,
                      cash: _controller.cash,
                      onTapBoost: () => _controller.tapBoostStation(i),
                      onUpgradeSpeed: () => _controller.upgradeSpeed(i),
                      onUpgradeBatch: () => _controller.upgradeBatch(i),
                    ),
                    if (i < _controller.stations.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            color: Color(0xFF334155),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildKpiHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF132242), Color(0xFF0E172E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FACTORY BALANCE',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(_controller.cash),
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpiPill(
                label: 'INCOME',
                value: formatRate(_controller.estimatedCashPerSec),
                color: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              _kpiPill(
                label: 'OUTPUT',
                value:
                    '${_controller.estimatedUnitsPerHour.toStringAsFixed(0)} u/hr',
                color: const Color(0xFFFFB300),
              ),
              const SizedBox(width: 8),
              _kpiPill(
                label: 'SHIPPED',
                value: formatCompactInt(_controller.totalUnitsShipped),
                color: const Color(0xFFB388FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF090D1A).withAlpha(150),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTierCard(ProductTier current, ProductTier? next) {
    final canUpgrade = next != null && _controller.cash >= next.unlockCost;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current.color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: current.color.withAlpha(32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(current.icon, color: current.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LINE MODEL: ${current.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${formatMoney(current.unitValue)} / unit shipped',
                  style: TextStyle(
                    color: current.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (next != null)
            FilledButton(
              onPressed: canUpgrade ? _controller.upgradeProductTier : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF090D1A),
                disabledBackgroundColor: const Color(0xFF1E293B),
                disabledForegroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R&D ${next.name.split(' ').first}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    formatMoney(next.unlockCost),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD500F9).withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'MAX TIER',
                style: TextStyle(
                  color: Color(0xFFD500F9),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTurboBar() {
    final active = _controller.isTurboActive;
    final ready = _controller.canActivateTurbo;
    final secs = active
        ? _controller.turboRemainingSeconds.ceil()
        : _controller.turboCooldownSeconds.ceil();

    final label = active
        ? 'OVERDRIVE TURBO 2X ACTIVE (${secs}s)'
        : ready
            ? 'ACTIVATE 2X OVERDRIVE TURBO (30s)'
            : 'TURBO RECHARGING (${secs}s)';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: ready ? _controller.activateTurbo : null,
        icon: Icon(
          active ? Icons.local_fire_department_rounded : Icons.flash_on_rounded,
          size: 20,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            fontSize: 12.5,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              active ? const Color(0xFFFF7043) : const Color(0xFF00E5FF),
          foregroundColor: const Color(0xFF090D1A),
          disabledBackgroundColor: active
              ? const Color(0xFFFF7043)
              : const Color(0xFF1E293B),
          disabledForegroundColor:
              active ? const Color(0xFF090D1A) : const Color(0xFF64748B),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
