import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/sound_service.dart';
import '../../utils/game_orientation.dart';

class CongklakScreen extends StatefulWidget {
  const CongklakScreen({super.key});

  @override
  State<CongklakScreen> createState() => _CongklakScreenState();
}

class _CongklakScreenState extends State<CongklakScreen> {
  static const String _bestKey = 'nufat_congklak_best_v1';
  // Pits 0..6: Player's small holes (left to right on bottom row)
  // Pit 7: Player's Lumbung (right, circular)
  // Pits 8..14: AI's small holes (right to left on top row)
  // Pit 15: AI's Lumbung (left, circular)
  late List<int> _pits;
  bool _playerTurn = true;
  bool _vsAi = true;
  bool _animating = false;
  bool _gameOver = false;
  bool _muted = false;
  int? _activePit;
  int? _dropPulsePit;
  int _inHand = 0;
  int _bestScore = 0;
  String _status = 'Giliranmu! Pilih lubang di baris bawah.';

  // Smooth hand-sowing overlay coordinates inside _boardStackKey
  final GlobalKey _boardStackKey = GlobalKey();
  final List<GlobalKey> _pitKeys = List.generate(16, (_) => GlobalKey());
  Offset? _handPos;
  bool _handVisible = false;
  bool _handDropping = false;
  bool _handIsPlayer = true;

  final Random _rng = Random();
  final SoundService _sfx = SoundService();

  @override
  void initState() {
    super.initState();
    GameOrientation.lockLandscape();
    _loadBest();
    _resetGame();
  }

  @override
  void dispose() {
    _sfx.dispose();
    GameOrientation.lockPortrait();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _sfx.isMuted = _muted;
    });
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _bestScore = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveBest(int val) async {
    if (val <= _bestScore) return;
    _bestScore = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, val);
    } catch (_) {}
  }

  void _resetGame() {
    _pits = List<int>.filled(16, 7);
    _pits[7] = 0;
    _pits[15] = 0;
    _playerTurn = true;
    _animating = false;
    _gameOver = false;
    _activePit = null;
    _dropPulsePit = null;
    _inHand = 0;
    _handVisible = false;
    _handDropping = false;
    _handPos = null;
    _status = 'Giliranmu! Pilih lubang di baris bawah.';
    setState(() {});
  }

  Offset? _pitCenterInBoard(int pitIdx) {
    final stackCtx = _boardStackKey.currentContext;
    final pitCtx = _pitKeys[pitIdx].currentContext;
    if (stackCtx == null || pitCtx == null) return null;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    final pitBox = pitCtx.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize || pitBox == null || !pitBox.hasSize) {
      return null;
    }
    final pitCenterGlobal = pitBox.localToGlobal(pitBox.size.center(Offset.zero));
    return stackBox.globalToLocal(pitCenterGlobal);
  }

  bool _sideEmpty(bool isPlayer) {
    final start = isPlayer ? 0 : 8;
    for (int i = start; i < start + 7; i++) {
      if (_pits[i] > 0) return false;
    }
    return true;
  }

  Future<void> _playPit(int startIdx) async {
    if (_animating || _gameOver) return;
    if (_playerTurn && (startIdx < 0 || startIdx > 6)) return;
    if (!_playerTurn && (startIdx < 8 || startIdx > 14)) return;
    if (_pits[startIdx] == 0) return;

    final isPlayer = _playerTurn;
    final myStore = isPlayer ? 7 : 15;
    final oppStore = isPlayer ? 15 : 7;
    final startPos = _pitCenterInBoard(startIdx);

    setState(() {
      _animating = true;
      _handIsPlayer = isPlayer;
      _inHand = _pits[startIdx];
      _pits[startIdx] = 0;
      _activePit = startIdx;
      _dropPulsePit = startIdx;
      _handPos = startPos;
      _handVisible = startPos != null;
      _handDropping = false;
      _status = '${isPlayer ? "Kamu" : (_vsAi ? "Bot AI" : "Pemain 2")} mengambil $_inHand biji...';
    });
    HapticFeedback.selectionClick();
    _sfx.playLaser();

    // Brief scoop pause so player sees the hand lift seeds from the starting pit
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    int cur = startIdx;
    while (_inHand > 0) {
      cur = (cur + 1) % 16;
      if (cur == oppStore) cur = (cur + 1) % 16;

      // Step 1: Smoothly glide hand to the next pit
      final nextPos = _pitCenterInBoard(cur);
      setState(() {
        _activePit = cur;
        _dropPulsePit = null;
        if (nextPos != null) _handPos = nextPos;
        _handDropping = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 195));
      if (!mounted) return;

      // Step 2: Drop 1 seed smoothly into the pit with subtle bounce + sound
      setState(() {
        _pits[cur]++;
        _inHand--;
        _dropPulsePit = cur;
        _handDropping = true;
      });
      _sfx.playCoin();

      await Future<void>.delayed(const Duration(milliseconds: 95));
      if (!mounted) return;

      // If last seed lands in a non-empty small pit, scoop up and keep sowing
      if (_inHand == 0 && cur != myStore && _pits[cur] > 1) {
        setState(() {
          _handDropping = false;
          _status = 'Ambil ${_pits[cur]} biji, lanjut menebar!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 230));
        if (!mounted) return;
        HapticFeedback.selectionClick();
        _sfx.playLaser();
        setState(() {
          _inHand = _pits[cur];
          _pits[cur] = 0;
          _dropPulsePit = cur;
        });
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
      }
    }

    // Capture ("Tembak") if last seed landed in empty pit on own side
    final onOwnSide = isPlayer ? (cur >= 0 && cur <= 6) : (cur >= 8 && cur <= 14);
    if (onOwnSide && _pits[cur] == 1) {
      final opposite = 14 - cur;
      if (_pits[opposite] > 0) {
        final captured = _pits[opposite] + 1;
        final oppPos = _pitCenterInBoard(opposite);
        if (oppPos != null) {
          setState(() {
            _handPos = oppPos;
            _activePit = opposite;
            _status = 'TEMBAK! Mengambil $captured biji lawan...';
          });
          await Future<void>.delayed(const Duration(milliseconds: 220));
          if (!mounted) return;
        }
        final storePos = _pitCenterInBoard(myStore);
        HapticFeedback.heavyImpact();
        _sfx.playEmp();
        setState(() {
          _pits[cur] = 0;
          _pits[opposite] = 0;
          _inHand = captured;
          if (storePos != null) _handPos = storePos;
          _activePit = myStore;
        });
        await Future<void>.delayed(const Duration(milliseconds: 240));
        if (!mounted) return;
        setState(() {
          _pits[myStore] += captured;
          _inHand = 0;
          _dropPulsePit = myStore;
          _status = 'TEMBAK! +$captured biji masuk lumbung!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
      }
    }

    // Check game over
    if (_sideEmpty(true) || _sideEmpty(false)) {
      for (int i = 0; i < 7; i++) {
        _pits[7] += _pits[i];
        _pits[i] = 0;
      }
      for (int i = 8; i < 15; i++) {
        _pits[15] += _pits[i];
        _pits[i] = 0;
      }
      _saveBest(_pits[7]);
      _sfx.playPowerUp();
      setState(() {
        _animating = false;
        _gameOver = true;
        _activePit = null;
        _dropPulsePit = null;
        _handVisible = false;
        if (_pits[7] > _pits[15]) {
          _status = 'KAMU MENANG! (${_pits[7]} vs ${_pits[15]})';
        } else if (_pits[7] < _pits[15]) {
          _status = '${_vsAi ? "BOT AI" : "PEMAIN 2"} MENANG! (${_pits[15]} vs ${_pits[7]})';
        } else {
          _status = 'SERI! (${_pits[7]} vs ${_pits[15]})';
        }
      });
      return;
    }

    final extraTurn = cur == myStore;
    if (extraTurn) {
      HapticFeedback.mediumImpact();
      _sfx.playPowerUp();
    }

    setState(() {
      _animating = false;
      _activePit = null;
      _dropPulsePit = null;
      _handVisible = false;
      _handDropping = false;
      if (!extraTurn) {
        _playerTurn = !_playerTurn;
      }
      if (extraTurn) {
        _status = isPlayer
            ? 'Masuk Lumbung! Giliran ekstra untukmu!'
            : '${_vsAi ? "Bot AI" : "Pemain 2"} masuk lumbung — giliran ekstra!';
      } else {
        _status = _playerTurn
            ? 'Giliranmu! Pilih lubang di baris bawah.'
            : 'Giliran ${_vsAi ? "Bot AI" : "Pemain 2"}...';
      }
    });

    if (!_playerTurn && _vsAi && !_gameOver) {
      _runAiTurn();
    }
  }

  Future<void> _runAiTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || _gameOver || _playerTurn || _animating) return;

    final valid = <int>[];
    for (int i = 8; i <= 14; i++) {
      if (_pits[i] > 0) valid.add(i);
    }
    if (valid.isEmpty) return;

    int? chosen;
    for (final idx in valid) {
      if (idx + _pits[idx] == 15) {
        chosen = idx;
        break;
      }
    }
    chosen ??= valid[_rng.nextInt(valid.length)];
    await _playPit(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140C07),
      body: Stack(
        children: [
          // Deep warm wooden tabletop backdrop with soft studio spotlight
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 1.15,
                colors: [Color(0xFF3A2213), Color(0xFF1B100A), Color(0xFF0E0805)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: [
                  // Sleek Horizontal Top HUD
                  Row(
                    children: [
                      _HudIconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONGKLAK ORI',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Dakon Kayu 3D Nusantara',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_playerTurn ? const Color(0xFFF59E0B) : const Color(0xFFFF6B35))
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            _status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'Rekor: $_bestScore',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _animating
                            ? null
                            : () {
                                setState(() => _vsAi = !_vsAi);
                                _resetGame();
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            _vsAi ? 'vs AI' : '2 Pemain',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _HudIconBtn(
                        icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        iconColor: _muted ? Colors.white38 : const Color(0xFFFDE68A),
                        onTap: _toggleMute,
                      ),
                      const SizedBox(width: 6),
                      _HudIconBtn(
                        icon: Icons.refresh_rounded,
                        onTap: _resetGame,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3D Sculpted Wooden Congklak Board + Floating Hand Animation Layer
                  Expanded(
                    child: Center(
                      child: Stack(
                        key: _boardStackKey,
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 3D Wooden Slab Base (bottom thickness lip)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 274),
                            padding: const EdgeInsets.only(bottom: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B1407),
                              borderRadius: BorderRadius.circular(112),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.78),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFA6602E), // sunlit top wood bevel
                                    Color(0xFF7A421C), // rich teak midtone
                                    Color(0xFF562B10), // deep mahogany base
                                    Color(0xFF3E1E0B), // lower bevel
                                  ],
                                  stops: [0.0, 0.22, 0.78, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(110),
                                border: Border.all(
                                  color: const Color(0xFFE3B25B),
                                  width: 2.6,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(107),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(painter: _WoodGrain3DPainter()),
                                    ),
                                    // Top glossy lacquer highlight strip
                                    Positioned(
                                      top: 0,
                                      left: 36,
                                      right: 36,
                                      height: 14,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white.withValues(alpha: 0.22),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      child: Row(
                                        children: [
                                          // Left ROUND Carved Lumbung (AI / Pemain 2)
                                          _RoundLumbung3D(
                                            pitKey: _pitKeys[15],
                                            label: _vsAi ? 'AI' : 'P2',
                                            count: _pits[15],
                                            highlighted: _activePit == 15,
                                            pulsing: _dropPulsePit == 15,
                                            isTurn: !_playerTurn && !_gameOver,
                                            accent: const Color(0xFFFF7849),
                                          ),
                                          const SizedBox(width: 12),
                                          // Center 2 Horizontal Rows of 7 3D Carved Pits
                                          Expanded(
                                            child: Column(
                                              children: [
                                                // Top Row: Opponent (14 down to 8)
                                                Expanded(
                                                  child: Row(
                                                    children: List.generate(7, (col) {
                                                      final idx = 14 - col;
                                                      return Expanded(
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: _CarvedHole3D(
                                                            pitKey: _pitKeys[idx],
                                                            count: _pits[idx],
                                                            active: _activePit == idx,
                                                            pulsing: _dropPulsePit == idx,
                                                            playable: !_playerTurn && !_vsAi && !_animating && _pits[idx] > 0,
                                                            accent: const Color(0xFFFF7849),
                                                            onTap: () => _playPit(idx),
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                                // Carved Center Wood Ridge
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        _vsAi ? '▲ LAWAN (AI)' : '▲ PEMAIN 2',
                                                        style: TextStyle(
                                                          color: const Color(0xFFFDE68A).withValues(alpha: 0.58),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.7,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          height: 2,
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(99),
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                const Color(0xFFE3B25B).withValues(alpha: 0.12),
                                                                const Color(0xFFE3B25B).withValues(alpha: 0.6),
                                                                const Color(0xFFE3B25B).withValues(alpha: 0.12),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '▼ BARISMU',
                                                        style: TextStyle(
                                                          color: const Color(0xFFFDE68A).withValues(alpha: 0.88),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.7,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Bottom Row: Player (0 to 6)
                                                Expanded(
                                                  child: Row(
                                                    children: List.generate(7, (col) {
                                                      final idx = col;
                                                      return Expanded(
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                                          child: _CarvedHole3D(
                                                            pitKey: _pitKeys[idx],
                                                            count: _pits[idx],
                                                            active: _activePit == idx,
                                                            pulsing: _dropPulsePit == idx,
                                                            playable: _playerTurn && !_animating && _pits[idx] > 0,
                                                            accent: const Color(0xFFFBBF24),
                                                            onTap: () => _playPit(idx),
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Right ROUND Carved Lumbung (Player)
                                          _RoundLumbung3D(
                                            pitKey: _pitKeys[7],
                                            label: 'KAMU',
                                            count: _pits[7],
                                            highlighted: _activePit == 7,
                                            pulsing: _dropPulsePit == 7,
                                            isTurn: _playerTurn && !_gameOver,
                                            accent: const Color(0xFFFBBF24),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Smooth Floating Sowing Hand gliding one-by-one from pit to pit!
                          if (_handVisible && _handPos != null)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 185),
                              curve: Curves.easeInOutCubic,
                              left: _handPos!.dx - 24,
                              top: _handPos!.dy - (_handDropping ? 18 : 30),
                              child: IgnorePointer(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 110),
                                  scale: _handDropping ? 0.90 : 1.05,
                                  child: _SowingHandBadge(
                                    inHand: _inHand,
                                    accent: _handIsPlayer
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFFF7849),
                                    dropping: _handDropping,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_gameOver)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26160D),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE3B25B), width: 1.8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rekor Lumbung Terbaik: $_bestScore biji',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF1A0E07),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _resetGame,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SowingHandBadge extends StatelessWidget {
  const _SowingHandBadge({
    required this.inHand,
    required this.accent,
    required this.dropping,
  });

  final int inHand;
  final Color accent;
  final bool dropping;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, Colors.white, 0.35)!,
                accent,
              ],
            ),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.65),
                blurRadius: 14,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pan_tool_alt_rounded, size: 15, color: Color(0xFF1A0E07)),
              const SizedBox(width: 4),
              Text(
                '$inHand',
                style: const TextStyle(
                  color: Color(0xFF1A0E07),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (dropping)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [Colors.white, accent],
              ),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.8), blurRadius: 6),
              ],
            ),
          ),
      ],
    );
  }
}

class _HudIconBtn extends StatelessWidget {
  const _HudIconBtn({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}

/// Round 3D Carved Wooden Lumbung (Markas) at left and right ends of the board.
class _RoundLumbung3D extends StatelessWidget {
  const _RoundLumbung3D({
    required this.pitKey,
    required this.label,
    required this.count,
    required this.highlighted,
    required this.pulsing,
    required this.isTurn,
    required this.accent,
  });

  final GlobalKey pitKey;
  final String label;
  final int count;
  final bool highlighted;
  final bool pulsing;
  final bool isTurn;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTurn ? accent : const Color(0xFFFDE68A).withValues(alpha: 0.65),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: pulsing ? 1.07 : 1.0,
            child: Stack(
              key: pitKey,
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer 3D carved bevel ring
                Container(
                  width: 106,
                  height: 106,
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3A1C0A), // top-left shadow lip
                        Color(0xFF6B3917),
                        Color(0xFFC48244), // sunlit bottom-right wood rim
                      ],
                    ),
                    border: Border.all(
                      color: highlighted
                          ? Colors.white
                          : isTurn
                              ? accent
                              : const Color(0xFFE3B25B).withValues(alpha: 0.45),
                      width: highlighted ? 2.4 : (isTurn ? 2.0 : 1.2),
                    ),
                    boxShadow: [
                      if (highlighted || isTurn)
                        BoxShadow(color: accent.withValues(alpha: 0.42), blurRadius: 16),
                    ],
                  ),
                  // Deep 3D concave wooden bowl interior
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(0.28, 0.28),
                        radius: 0.92,
                        colors: [
                          Color(0xFF3E1E0C), // lit bottom-right floor
                          Color(0xFF231006), // deep center
                          Color(0xFF110702), // dark top-left inner wall
                        ],
                        stops: [0.0, 0.58, 1.0],
                      ),
                    ),
                    child: _SeedCluster3D(count: count, maxDots: 20, accent: accent),
                  ),
                ),
                // Crisp numeric badge at bottom rim
                Positioned(
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0D06),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: accent, width: 1.4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round 3D Carved Small Congklak Hole with concave lighting & seed drop pulse.
class _CarvedHole3D extends StatelessWidget {
  const _CarvedHole3D({
    required this.pitKey,
    required this.count,
    required this.active,
    required this.pulsing,
    required this.playable,
    required this.accent,
    required this.onTap,
  });

  final GlobalKey pitKey;
  final int count;
  final bool active;
  final bool pulsing;
  final bool playable;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: playable ? onTap : null,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 110),
              scale: pulsing ? 1.10 : 1.0,
              child: Stack(
                key: pitKey,
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer 3D carved bevel rim
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    width: size,
                    height: size,
                    padding: const EdgeInsets.all(3.2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF331808),
                          Color(0xFF693716),
                          Color(0xFFBE7B3E),
                        ],
                      ),
                      border: Border.all(
                        color: active
                            ? Colors.white
                            : playable
                                ? accent.withValues(alpha: 0.9)
                                : const Color(0xFFE3B25B).withValues(alpha: 0.25),
                        width: active ? 2.2 : (playable ? 1.7 : 1.0),
                      ),
                      boxShadow: [
                        if (active || playable)
                          BoxShadow(
                            color: accent.withValues(alpha: active ? 0.55 : 0.22),
                            blurRadius: active ? 13 : 6,
                          ),
                      ],
                    ),
                    // Deep concave interior shadow
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(0.28, 0.28),
                          radius: 0.92,
                          colors: active
                              ? [
                                  Color.lerp(const Color(0xFF3B1D0B), accent, 0.28)!,
                                  const Color(0xFF210F05),
                                  const Color(0xFF100702),
                                ]
                              : const [
                                  Color(0xFF3B1D0B),
                                  Color(0xFF200E05),
                                  Color(0xFF0F0602),
                                ],
                          stops: const [0.0, 0.56, 1.0],
                        ),
                      ),
                      child: _SeedCluster3D(count: count, maxDots: 12, accent: accent),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D06),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: count > 0 ? accent.withValues(alpha: 0.75) : Colors.white12,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: count > 0 ? Colors.white : Colors.white30,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Glossy 3D cowrie/seed cluster rendered inside carved Congklak bowls.
class _SeedCluster3D extends StatelessWidget {
  const _SeedCluster3D({
    required this.count,
    required this.maxDots,
    required this.accent,
  });

  final int count;
  final int maxDots;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final shown = min(count, maxDots);
    return LayoutBuilder(
      builder: (_, box) {
        final cx = box.maxWidth / 2;
        final cy = box.maxHeight / 2;
        final radius = min(cx, cy) * 0.64;
        return Stack(
          children: List.generate(shown, (i) {
            final ring = i == 0 ? 0.0 : (i <= 6 ? 0.52 : 0.90);
            final angle = i * 2.39996;
            final dx = cx + cos(angle) * radius * ring - 4.6;
            final dy = cy + sin(angle) * radius * ring - 4.0;
            return Positioned(
              left: dx.clamp(1.0, max(1.0, box.maxWidth - 10.5)),
              top: dy.clamp(1.0, max(1.0, box.maxHeight - 9.5)),
              child: Container(
                width: 9.4,
                height: 8.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: RadialGradient(
                    center: const Alignment(-0.38, -0.38),
                    colors: [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFFFF3C4),
                      Color.lerp(const Color(0xFFE6A566), accent, 0.32)!,
                      const Color(0xFF78350F),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 2.5, offset: Offset(0, 1.4)),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _WoodGrain3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkGrain = Paint()
      ..color = Colors.black.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final lightGrain = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double y = 12; y < size.height; y += 16) {
      final path = Path()..moveTo(0, y);
      path.quadraticBezierTo(size.width * 0.35, y + 7, size.width * 0.7, y - 5);
      path.quadraticBezierTo(size.width * 0.88, y - 9, size.width, y + 2);
      canvas.drawPath(path, darkGrain);
      canvas.drawPath(path.shift(const Offset(0, 2)), lightGrain);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
