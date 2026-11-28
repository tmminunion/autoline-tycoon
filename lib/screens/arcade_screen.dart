import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/entities.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ArcadeGameEngine _engine = ArcadeGameEngine();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine.loadPrefs();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _engine.update(dt);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_engine.phase == GamePhase.playing) {
        _engine.togglePause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _engine.setViewport(Size(constraints.maxWidth, constraints.maxHeight));

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-screen 60 FPS Arcade Canvas + One-Finger Touch Control
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _engine.setTouchPosition(d.localPosition),
                onPanUpdate: (d) => _engine.setTouchPosition(d.localPosition),
                onTapDown: (d) => _engine.setTouchPosition(d.localPosition),
                child: CustomPaint(
                  painter: ArcadeGamePainter(_engine),
                  size: Size.infinite,
                ),
              ),

              // 2. Minimal Floating Arcade HUD & Overlays
              AnimatedBuilder(
                animation: _engine,
                builder: (context, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_engine.phase == GamePhase.playing ||
                          _engine.phase == GamePhase.paused)
                        _buildTopHud(),
                      if (_engine.phase == GamePhase.playing &&
                          _engine.activeBoss != null)
                        _buildBossBar(_engine.activeBoss!),
                      if (_engine.phase == GamePhase.playing) _buildEmpButton(),
                      if (_engine.phase == GamePhase.title) _buildTitleOverlay(),
                      if (_engine.phase == GamePhase.hangar)
                        _buildHangarOverlay(),
                      if (_engine.phase == GamePhase.paused)
                        _buildPauseOverlay(),
                      if (_engine.phase == GamePhase.gameOver)
                        _buildGameOverOverlay(),
                      if (Navigator.of(context).canPop() &&
                          (_engine.phase == GamePhase.title ||
                              _engine.phase == GamePhase.paused ||
                              _engine.phase == GamePhase.gameOver))
                        Positioned(
                          top: 12,
                          left: 12,
                          child: SafeArea(
                            child: Material(
                              color: const Color(0xCC071024),
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => Navigator.of(context).maybePop(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0x6600E5FF)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFF00E5FF)),
                                      SizedBox(width: 5),
                                      Text(
                                        'HUB',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoinChip(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1A).withAlpha(170),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD740).withAlpha(140)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFD740),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            '$amount',
            style: const TextStyle(
              color: Color(0xFFFFD740),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHud() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _engine.score.toString().padLeft(6, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(color: Color(0xFF00E5FF), blurRadius: 10),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'WAVE ${_engine.wave}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFFFD740),
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_engine.coins}',
                        style: const TextStyle(
                          color: Color(0xFFFFD740),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_engine.combo >= 3) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${_engine.combo}x',
                          style: const TextStyle(
                            color: Color(0xFFFF4081),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (int i = 0; i < _engine.maxHp; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: i < _engine.hp
                                ? const Color(0xFFFF4081)
                                : const Color(0xFF334155),
                          ),
                        ),
                      if (_engine.hasShield)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.shield_rounded,
                            size: 16,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'WPN LV.${_engine.weaponLevel}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _hudIconButton(
                    icon: _engine.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: _engine.isMuted
                        ? const Color(0xFF64748B)
                        : const Color(0xFF00E5FF),
                    onTap: _engine.toggleMute,
                  ),
                  const SizedBox(width: 8),
                  _hudIconButton(
                    icon: _engine.phase == GamePhase.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white,
                    onTap: _engine.togglePause,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF090D1A).withAlpha(160),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(120), width: 1.2),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildBossBar(Enemy boss) {
    final ratio = (boss.hp / boss.maxHp).clamp(0.0, 1.0);
    return Positioned(
      top: 92,
      left: 24,
      right: 24,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Text(
              'DREADNOUGHT BOSS',
              style: TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF1744)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpButton() {
    final enabled = _engine.empCharges > 0;
    return Positioned(
      right: 18,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: enabled ? _engine.triggerEmp : null,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? const Color(0xFFFF4081).withAlpha(55)
                  : const Color(0xFF1E293B).withAlpha(100),
              border: Border.all(
                color: enabled
                    ? const Color(0xFFFF4081)
                    : const Color(0xFF475569),
                width: 2.2,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF4081).withAlpha(110),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: enabled
                      ? const Color(0xFFFF4081)
                      : const Color(0xFF64748B),
                  size: 24,
                ),
                Text(
                  'EMP ${_engine.empCharges}',
                  style: TextStyle(
                    color: enabled ? Colors.white : const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleOverlay() {
    final spec = _engine.activeShipSpec;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCoinChip(_engine.coins),
                _hudIconButton(
                  icon: _engine.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _engine.isMuted
                      ? const Color(0xFF64748B)
                      : const Color(0xFF00E5FF),
                  onTap: _engine.toggleMute,
                ),
              ],
            ),
            const Spacer(flex: 2),
            const Text(
              'NEON',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                height: 0.95,
                shadows: [
                  Shadow(color: Color(0xFF00E5FF), blurRadius: 24),
                ],
              ),
            ),
            const Text(
              'STRIKER',
              style: TextStyle(
                color: Color(0xFFFF4081),
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                height: 1.05,
                shadows: [
                  Shadow(color: Color(0xFFFF4081), blurRadius: 24),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'FIGHTER: ${spec.name}',
              style: TextStyle(
                color: spec.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.6,
              ),
            ),
            if (_engine.highScore > 0) ...[
              const SizedBox(height: 12),
              Text(
                'BEST SCORE: ${_engine.highScore}',
                style: const TextStyle(
                  color: Color(0xFFFFD740),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
            const Spacer(flex: 4),
            SizedBox(
              width: 235,
              height: 54,
              child: FilledButton(
                onPressed: _engine.startGame,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF050714),
                  shape: const StadiumBorder(),
                  elevation: 10,
                  shadowColor: const Color(0xFF00E5FF),
                ),
                child: const Text(
                  'LAUNCH MISSION',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 235,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _engine.openHangar,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text(
                  'HANGAR & UPGRADES',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD740),
                  side: const BorderSide(color: Color(0xFFFFD740), width: 1.6),
                  shape: const StadiumBorder(),
                  backgroundColor: const Color(0xFF090D1A).withAlpha(150),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Geser 1 jari untuk terbang • Kumpulkan koin emas',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHangarOverlay() {
    final spec = kShipSpecs[_engine.previewShip]!;
    final unlocked = _engine.isShipUnlocked(_engine.previewShip);
    final equipped = _engine.selectedShip == _engine.previewShip;
    final canAffordShip = _engine.coins >= spec.unlockCost;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Column(
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _hudIconButton(
                  icon: Icons.arrow_back_rounded,
                  color: Colors.white,
                  onTap: _engine.returnToTitle,
                ),
                const Text(
                  'STARFIGHTER HANGAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
                _buildCoinChip(_engine.coins),
              ],
            ),

            // Space for the live 1.65x animated ship hovering on canvas
            const Spacer(flex: 5),

            // Fighter selector pills (3 ships)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ShipType.values.map((t) {
                final s = kShipSpecs[t]!;
                final active = _engine.previewShip == t;
                final isOwned = _engine.isShipUnlocked(t);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () => _engine.selectPreviewShip(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? s.primaryColor.withAlpha(45)
                            : const Color(0xFF090D1A).withAlpha(170),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? s.primaryColor
                              : const Color(0xFF334155),
                          width: active ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isOwned)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: active
                                    ? s.primaryColor
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          Text(
                            s.name,
                            style: TextStyle(
                              color: active ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Ship role & neon stat bars (minimal HUD, no boxy card)
            Text(
              spec.role,
              style: TextStyle(
                color: spec.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatBar(
              'HULL',
              (spec.baseHp + _engine.hullUpgradeLv) / 10.0,
              const Color(0xFFFF4081),
              '${spec.baseHp + _engine.hullUpgradeLv} HP',
            ),
            const SizedBox(height: 5),
            _buildStatBar(
              'FIRE',
              (spec.fireRateMult * (1 + _engine.fireUpgradeLv * 0.1) / 2.0)
                  .clamp(0.1, 1.0),
              spec.primaryColor,
              '${(spec.fireRateMult * (1 + _engine.fireUpgradeLv * 0.1) * 100).round()}%',
            ),
            const SizedBox(height: 5),
            _buildStatBar(
              'AGILITY',
              (spec.moveFollowSpeed / 26.0).clamp(0.2, 1.0),
              const Color(0xFF00E676),
              'COINS x${spec.coinMult.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 14),

            // Permanent Coin Upgrades (3 sleek HUD rows)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PERMANENT TECH UPGRADES',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildUpgradeRow(
              label: 'HULL ARMOR (+1 HP)',
              level: _engine.hullUpgradeLv,
              cost: _engine.hullUpgradeCost,
              color: const Color(0xFFFF4081),
              onUpgrade: _engine.buyHullUpgrade,
            ),
            const SizedBox(height: 7),
            _buildUpgradeRow(
              label: 'PLASMA CORE (+10% ROF)',
              level: _engine.fireUpgradeLv,
              cost: _engine.fireUpgradeCost,
              color: const Color(0xFF00E5FF),
              onUpgrade: _engine.buyFireUpgrade,
            ),
            const SizedBox(height: 7),
            _buildUpgradeRow(
              label: 'MAGNET & EMP (+RANGE)',
              level: _engine.magnetUpgradeLv,
              cost: _engine.magnetUpgradeCost,
              color: const Color(0xFFFFD740),
              onUpgrade: _engine.buyMagnetUpgrade,
            ),

            const Spacer(flex: 1),

            // Bottom action button: UNLOCK or DEPLOY
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: unlocked
                    ? (equipped
                        ? _engine.startGame
                        : _engine.unlockOrEquipPreviewShip)
                    : (canAffordShip ? _engine.unlockOrEquipPreviewShip : null),
                style: FilledButton.styleFrom(
                  backgroundColor: unlocked
                      ? spec.primaryColor
                      : const Color(0xFFFFD740),
                  foregroundColor: const Color(0xFF050714),
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  disabledForegroundColor: const Color(0xFF64748B),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  unlocked
                      ? (equipped ? 'DEPLOY ${spec.name}' : 'EQUIP ${spec.name}')
                      : 'UNLOCK ${spec.name} (${spec.unlockCost} COINS)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, double ratio, Color color, String value) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.05, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeRow({
    required String label,
    required int level,
    required int cost,
    required Color color,
    required VoidCallback onUpgrade,
  }) {
    final isMax = level >= ArcadeGameEngine.maxUpgradeLevel;
    final canAfford = !isMax && _engine.coins >= cost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D1A).withAlpha(175),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (int i = 0; i < ArcadeGameEngine.maxUpgradeLevel; i++)
                      Container(
                        width: 22,
                        height: 5,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: i < level ? color : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: canAfford ? onUpgrade : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isMax
                    ? const Color(0xFF00E676).withAlpha(35)
                    : (canAfford
                        ? color.withAlpha(45)
                        : const Color(0xFF1E293B)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMax
                      ? const Color(0xFF00E676)
                      : (canAfford ? color : const Color(0xFF334155)),
                ),
              ),
              child: Text(
                isMax ? 'MAX' : '$cost C',
                style: TextStyle(
                  color: isMax
                      ? const Color(0xFF00E676)
                      : (canAfford ? Colors.white : const Color(0xFF64748B)),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: const Color(0xFF050714).withAlpha(185),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              height: 48,
              child: FilledButton(
                onPressed: _engine.togglePause,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF050714),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'RESUME',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _engine.returnToTitle,
              child: const Text(
                'MAIN MENU',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: const Color(0xFF050714).withAlpha(205),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SHIP DESTROYED',
              style: TextStyle(
                color: Color(0xFFFF4081),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: Color(0xFFFF4081), blurRadius: 18),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${_engine.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              'WAVE ${_engine.wave}  •  BEST ${_engine.highScore}',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '+${_engine.runCoins} COINS EARNED  (TOTAL: ${_engine.coins})',
              style: const TextStyle(
                color: Color(0xFFFFD740),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              height: 50,
              child: FilledButton(
                onPressed: _engine.startGame,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF050714),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 44,
              child: OutlinedButton(
                onPressed: _engine.openHangar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD740),
                  side: const BorderSide(color: Color(0xFFFFD740), width: 1.5),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'HANGAR & UPGRADES',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _engine.returnToTitle,
              child: const Text(
                'TITLE SCREEN',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
