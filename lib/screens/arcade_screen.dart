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
                      if (_engine.phase == GamePhase.paused) _buildPauseOverlay(),
                      if (_engine.phase == GamePhase.gameOver)
                        _buildGameOverOverlay(),
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
              // Score + Combo
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
                      if (_engine.combo >= 3) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${_engine.combo}x COMBO',
                          style: const TextStyle(
                            color: Color(0xFFFFD740),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Hull HP + Shield indicators
                  Row(
                    children: [
                      for (int i = 0; i < _engine.maxHp; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 18,
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
                            size: 18,
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
              // Audio & Pause icon buttons
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
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
            const SizedBox(height: 14),
            const Text(
              'CYBERPUNK ARCADE SHOOTER',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
              ),
            ),
            if (_engine.highScore > 0) ...[
              const SizedBox(height: 18),
              Text(
                'BEST SCORE: ${_engine.highScore}',
                style: const TextStyle(
                  color: Color(0xFFFFD740),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
            const Spacer(flex: 4),
            SizedBox(
              width: 230,
              height: 56,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Geser 1 jari untuk terbang • Auto-Fire aktif',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
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
      color: const Color(0xFF050714).withAlpha(200),
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
            const SizedBox(height: 20),
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
                color: Color(0xFFFFD740),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 210,
              height: 52,
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
