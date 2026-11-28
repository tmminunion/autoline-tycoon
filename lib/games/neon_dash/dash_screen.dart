import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dash_engine.dart';
import 'dash_painter.dart';

class DashScreen extends StatefulWidget {
  const DashScreen({super.key});

  @override
  State<DashScreen> createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DashEngine _engine = DashEngine();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double? _dragStartY;

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_engine.phase == DashPhase.playing) {
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
      backgroundColor: const Color(0xFF040916),
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD
            AnimatedBuilder(
              animation: _engine,
              builder: (context, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF071024),
                  border: Border(bottom: BorderSide(color: Color(0x3322D3EE))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    _HudChip(label: 'SKOR', value: '${_engine.score.floor()}', color: const Color(0xFF22D3EE)),
                    const SizedBox(width: 6),
                    _HudChip(label: 'JARAK', value: '${_engine.distance.floor()}m', color: Colors.white),
                    const SizedBox(width: 6),
                    _HudChip(label: 'KOIN', value: '${_engine.runCoins}', color: const Color(0xFFFACC15)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _engine.togglePause,
                      icon: Icon(
                        _engine.phase == DashPhase.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: const Color(0xFF22D3EE),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Canvas Stage
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _engine.setViewport(Size(constraints.maxWidth, constraints.maxHeight));
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _engine.jump,
                        onVerticalDragStart: (d) => _dragStartY = d.localPosition.dy,
                        onVerticalDragUpdate: (d) {
                          if (_dragStartY != null && d.localPosition.dy - _dragStartY! > 30) {
                            _engine.slide();
                            _dragStartY = null;
                          }
                        },
                        onVerticalDragEnd: (_) => _dragStartY = null,
                        child: CustomPaint(
                          painter: DashPainter(_engine),
                          size: Size.infinite,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _engine,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPowerBadges(),
                            if (_engine.phase == DashPhase.title) _buildTitleOverlay(),
                            if (_engine.phase == DashPhase.paused) _buildPauseOverlay(),
                            if (_engine.phase == DashPhase.gameOver) _buildGameOverOverlay(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Touch Controls
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF071024),
                border: Border(top: BorderSide(color: Color(0x3322D3EE))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        foregroundColor: const Color(0xFFFACC15),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0x66FACC15)),
                        ),
                      ),
                      onPressed: _engine.slide,
                      icon: const Icon(Icons.keyboard_double_arrow_down_rounded),
                      label: const Text('SLIDE', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7490),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFF22D3EE)),
                        ),
                      ),
                      onPressed: _engine.jump,
                      icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
                      label: const Text('LOMPAT', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerBadges() {
    final badges = <Widget>[];
    if (_engine.hasShield) {
      badges.add(const _PowerPill(text: 'SHIELD AKTIF', color: Color(0xFFFACC15)));
    }
    if (_engine.magnetTimer > 0) {
      badges.add(_PowerPill(text: 'MAGNET ${_engine.magnetTimer.toStringAsFixed(1)}s', color: const Color(0xFFC084FC)));
    }
    if (_engine.turboTimer > 0) {
      badges.add(_PowerPill(text: 'TURBO 2X ${_engine.turboTimer.toStringAsFixed(1)}s', color: const Color(0xFF22D3EE)));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 10,
      left: 12,
      child: Wrap(spacing: 6, runSpacing: 6, children: badges),
    );
  }

  Widget _buildTitleOverlay() {
    return Container(
      color: const Color(0xBB040916),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B162E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x6622D3EE), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 48, color: Color(0xFFFACC15)),
            const SizedBox(height: 8),
            const Text(
              'NEON DASH',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap untuk Lompat (Double Jump) & Swipe/Tekan SLIDE untuk hindari laser. Kumpulkan koin & power-up!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.45),
            ),
            if (_engine.bestScore > 0) ...[
              const SizedBox(height: 10),
              Text(
                'REKOR TERBAIK: ${_engine.bestScore}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: const Color(0xFF040916),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _engine.startGame,
                child: const Text('MULAI LARI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: const Color(0xBB040916),
      alignment: Alignment.center,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B162E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x6622D3EE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('JEDA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22D3EE), foregroundColor: const Color(0xFF040916)),
                onPressed: _engine.togglePause,
                child: const Text('LANJUTKAN', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Kembali ke Nufat Games', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: const Color(0xCC040916),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B162E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x66FB7185), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_engine.isNewBest)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x26FACC15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFACC15)),
                ),
                child: const Text('REKOR BARU!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFACC15))),
              ),
            const Text('GAME OVER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ResultCol(label: 'SKOR', value: '${_engine.score.floor()}'),
                _ResultCol(label: 'JARAK', value: '${_engine.distance.floor()}m'),
                _ResultCol(label: 'KOIN', value: '${_engine.runCoins}'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: const Color(0xFF040916),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _engine.startGame,
                child: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Kembali ke Nufat Games', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xD9071024),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

class _ResultCol extends StatelessWidget {
  const _ResultCol({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
