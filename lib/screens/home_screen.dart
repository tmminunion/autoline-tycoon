import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';
import '../utils/formatters.dart';
import '../widgets/station_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _saveKey = 'autoline_tycoon_state_v1';
  static const _tsKey = 'autoline_tycoon_last_ts_v1';

  GameState _state = GameState.initial();
  Timer? _gameTimer;
  Timer? _saveTimer;
  int _selectedTab = 0; // 0 = Lini Produksi, 1 = Kaizen & Prestige
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGame();
    _startLoops();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _saveTimer?.cancel();
    _saveGame();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveGame();
    }
  }

  void _startLoops() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _state.tick(0.1);
      });
    });

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveGame();
    });
  }

  Future<void> _loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      final lastTs = prefs.getInt(_tsKey);

      if (raw != null && raw.isNotEmpty) {
        final restored = GameState.fromJsonString(raw);
        double offlineEarned = 0;
        int elapsedSec = 0;

        if (lastTs != null) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          elapsedSec = max(0, (nowMs - lastTs) ~/ 1000);
          // Cap offline income at 8 hours, 50% offline efficiency
          final effectiveSec = min(elapsedSec, 8 * 3600);
          if (effectiveSec >= 15) {
            offlineEarned = restored.incomePerSecond * effectiveSec * 0.5;
            restored.cash += offlineEarned;
            restored.lifetimeCash += offlineEarned;
          }
        }

        if (mounted) {
          setState(() {
            _state = restored;
            _loaded = true;
          });
          if (offlineEarned >= 1.0) {
            _showOfflineDialog(elapsedSec, offlineEarned);
          }
        }
        return;
      }
    } catch (_) {
      // Fallback to fresh state if corrupted
    }

    if (mounted) {
      setState(() {
        _loaded = true;
      });
    }
  }

  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, _state.toJsonString());
      await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Ignore storage errors silently
    }
  }

  void _showOfflineDialog(int elapsedSec, double earned) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.factory, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text(
              'Produksi Offline',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pabrik tetap berjalan selama ${Formatters.duration(elapsedSec)} saat kamu pergi (efisiensi 50%).',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Pendapatan Terkumpul',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${Formatters.money(earned)}',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 26,
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
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF07101F),
            ),
            child: const Text(
              'KLAIM',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _onBoost(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _state.boostStation(index);
    });
  }

  void _onUpgradeStation(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _state.upgradeStation(index);
    });
    _saveGame();
  }

  void _confirmPrestige() {
    final gain = _state.claimableKaizenStars;
    if (gain <= 0) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFA855F7).withValues(alpha: 0.5),
          ),
        ),
        title: const Text(
          'Ekspansi Pabrik (Prestige)',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Reset level stasiun & uang saat ini untuk mendapatkan +$gain Kaizen Star.\n\nSetiap Kaizen Star memberi bonus profit permanen +50%!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              HapticFeedback.mediumImpact();
              setState(() {
                _state.prestigeReset();
              });
              _saveGame();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
            ),
            child: Text('Klaim +$gain ⭐'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottleneckIdx = _state.bottleneckIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              )
            : Column(
                children: [
                  _buildHeader(),
                  _buildTabSwitcher(),
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildProductionLine(bottleneckIdx)
                        : _buildKaizenTab(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16223A), Color(0xFF101828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.factory,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AUTOLINE TYCOON',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (_state.kaizenStars > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '⭐ ${_state.kaizenStars} (x${_state.prestigeMultiplier.toStringAsFixed(1)})',
                    style: const TextStyle(
                      color: Color(0xFFD8B4FE),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  Formatters.money(_state.cash),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${Formatters.money(_state.incomePerSecond)}/s',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Harga/unit: ${Formatters.money(_state.unitPrice)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statPill(
                Icons.trending_up,
                'Output',
                Formatters.rate(_state.effectiveUnitsPerMinute),
                const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 8),
              _statPill(
                Icons.inventory_2,
                'Total Unit',
                '${_state.unitsProduced}',
                const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _statPill(
                Icons.auto_awesome,
                'Batch',
                'x${_state.batchSize}',
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9.5,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabButton(0, 'Lini Produksi'),
          _tabButton(1, 'Kaizen & Prestige'),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF38BDF8) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? const Color(0xFF07101F)
                  : Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionLine(int bottleneckIdx) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _state.stations.length,
      itemBuilder: (context, i) {
        final station = _state.stations[i];
        return StationCard(
          index: i,
          station: station,
          isBottleneck: i == bottleneckIdx,
          canAffordUpgrade: _state.cash >= station.upgradeCost,
          onTapBoost: () => _onBoost(i),
          onUpgrade: () => _onUpgradeStation(i),
        );
      },
    );
  }

  Widget _buildKaizenTab() {
    final canAffordValue = _state.cash >= _state.unitValueUpgradeCost;
    final canAffordBatch = _state.cash >= _state.batchUpgradeCost;
    final claimableStars = _state.claimableKaizenStars;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _upgradeTile(
          icon: Icons.attach_money,
          color: const Color(0xFF10B981),
          title: 'Kualitas & Harga Jual (Lv.${_state.unitValueLevel})',
          subtitle: 'Naikkan harga jual setiap unit selesai +35%.',
          cost: _state.unitValueUpgradeCost,
          canAfford: canAffordValue,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _state.upgradeUnitValue());
            _saveGame();
          },
        ),
        _upgradeTile(
          icon: Icons.inventory_2,
          color: const Color(0xFFF59E0B),
          title: 'Kapasitas Batch (x${_state.batchSize})',
          subtitle: 'Tambah +1 unit keluar setiap siklus Quality Control.',
          cost: _state.batchUpgradeCost,
          canAfford: canAffordBatch,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _state.upgradeBatchSize());
            _saveGame();
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFC084FC)),
                  SizedBox(width: 8),
                  Text(
                    'Prestige: Kaizen Stars',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total pendapatan sepanjang waktu: ${Formatters.money(_state.lifetimeCash)}\n'
                'Target buka Prestige: ${Formatters.money(GameState.prestigeThreshold)}\n'
                'Kaizen Stars aktif: ${_state.kaizenStars} (+${_state.kaizenStars * 50}% profit)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: claimableStars > 0 ? _confirmPrestige : null,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    claimableStars > 0
                        ? 'PRESTIGE SEKARANG (+$claimableStars ⭐)'
                        : 'BELUM TERSEDIA (CAPAI \$50K)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA855F7),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _upgradeTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double cost,
    required bool canAfford,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: canAfford ? onTap : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: const Color(0xFF07101F),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.07),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              Formatters.money(cost),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
