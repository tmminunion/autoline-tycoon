import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Domino {
  const _Domino(this.a, this.b);
  final int a;
  final int b;

  int get pips => a + b;
  bool get isDouble => a == b;
  bool matches(int val) => a == val || b == val;

  @override
  bool operator ==(Object other) =>
      other is _Domino && ((a == other.a && b == other.b) || (a == other.b && b == other.a));

  @override
  int get hashCode => (a < b ? a * 7 + b : b * 7 + a).hashCode;
}

class _BoardTile {
  const _BoardTile(this.left, this.right);
  final int left;
  final int right;
  bool get isDouble => left == right;
}

class GapleScreen extends StatefulWidget {
  const GapleScreen({super.key});

  @override
  State<GapleScreen> createState() => _GapleScreenState();
}

class _GapleScreenState extends State<GapleScreen> {
  static const String _bestKey = 'nufat_gaple_best_v1';
  static const List<String> _names = ['Kamu', 'Bot Kiri', 'Bot Atas', 'Bot Kanan'];

  final Random _rng = Random();
  final ScrollController _chainScroll = ScrollController();

  late List<List<_Domino>> _hands;
  final List<_BoardTile> _chain = [];
  int? _leftEnd;
  int? _rightEnd;
  int _turn = 0; // 0 = Kamu, 1..3 = Bots
  int _consecutivePasses = 0;
  int _round = 1;
  int _totalScore = 0;
  int _bestScore = 0;
  String _statusMsg = 'Giliran dimulai...';
  _Domino? _pendingChoice;
  bool _roundOver = false;
  String _roundTitle = '';
  String _roundDetail = '';
  Timer? _botTimer;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _startRound(resetScore: true);
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _chainScroll.dispose();
    super.dispose();
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

  void _startRound({bool resetScore = false}) {
    _botTimer?.cancel();
    final deck = <_Domino>[];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        deck.add(_Domino(i, j));
      }
    }
    deck.shuffle(_rng);

    _hands = List.generate(4, (p) => deck.sublist(p * 7, (p + 1) * 7));
    _chain.clear();
    _leftEnd = null;
    _rightEnd = null;
    _consecutivePasses = 0;
    _pendingChoice = null;
    _roundOver = false;
    if (resetScore) {
      _round = 1;
      _totalScore = 0;
    }

    // Find holder of double-6 (6|6) to start
    int starter = 0;
    for (int p = 0; p < 4; p++) {
      if (_hands[p].any((d) => d.a == 6 && d.b == 6)) {
        starter = p;
        break;
      }
    }

    _turn = starter;
    _statusMsg = starter == 0
        ? 'Kamu pegang Balak 6! Pasang kartu pertama.'
        : '${_names[starter]} mulai dengan Balak 6...';
    setState(() {});

    if (_turn != 0) {
      _scheduleBotTurn();
    }
  }

  bool _canPlayTile(_Domino d) {
    if (_chain.isEmpty) return true;
    return d.matches(_leftEnd!) || d.matches(_rightEnd!);
  }

  List<_Domino> _playableTiles(int player) =>
      _hands[player].where(_canPlayTile).toList();

  void _placeTile(int player, _Domino tile, {required bool onLeft}) {
    _hands[player].remove(tile);
    if (_chain.isEmpty) {
      _chain.add(_BoardTile(tile.a, tile.b));
      _leftEnd = tile.a;
      _rightEnd = tile.b;
    } else if (onLeft) {
      final target = _leftEnd!;
      final placed = tile.b == target
          ? _BoardTile(tile.a, tile.b)
          : _BoardTile(tile.b, tile.a);
      _chain.insert(0, placed);
      _leftEnd = placed.left;
    } else {
      final target = _rightEnd!;
      final placed = tile.a == target
          ? _BoardTile(tile.a, tile.b)
          : _BoardTile(tile.b, tile.a);
      _chain.add(placed);
      _rightEnd = placed.right;
    }

    _consecutivePasses = 0;
    _pendingChoice = null;
    _statusMsg = '${_names[player]} pasang [${tile.a}|${tile.b}]';
    HapticFeedback.selectionClick();

    if (_hands[player].isEmpty) {
      _finishRound(winner: player, blocked: false);
      return;
    }

    _advanceTurn();
  }

  void _passTurn(int player) {
    _consecutivePasses++;
    _pendingChoice = null;
    _statusMsg = '${_names[player]} LEWAT (tidak ada kartu cocok)';

    if (_consecutivePasses >= 4) {
      // Blocked / Mati: lowest total pips wins
      int bestPlayer = 0;
      int lowestPips = 999;
      for (int p = 0; p < 4; p++) {
        final sum = _hands[p].fold<int>(0, (acc, d) => acc + d.pips);
        if (sum < lowestPips) {
          lowestPips = sum;
          bestPlayer = p;
        }
      }
      _finishRound(winner: bestPlayer, blocked: true);
      return;
    }

    _advanceTurn();
  }

  void _advanceTurn() {
    _turn = (_turn + 1) % 4;
    setState(() {});
    if (_turn != 0) {
      _scheduleBotTurn();
    }
  }

  void _scheduleBotTurn() {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 580), () {
      if (!mounted || _roundOver || _turn == 0) return;
      final p = _turn;
      final playable = _playableTiles(p);
      if (playable.isEmpty) {
        _passTurn(p);
        return;
      }

      // If first move, play double-6 if present
      _Domino chosen;
      if (_chain.isEmpty && playable.any((d) => d.a == 6 && d.b == 6)) {
        chosen = playable.firstWhere((d) => d.a == 6 && d.b == 6);
      } else {
        // Heuristic: shed highest-pip tile first, slight priority for doubles
        playable.sort((x, y) {
          final sx = x.pips + (x.isDouble ? 3 : 0);
          final sy = y.pips + (y.isDouble ? 3 : 0);
          return sy.compareTo(sx);
        });
        chosen = playable.first;
      }

      final fitsLeft = _chain.isEmpty || chosen.matches(_leftEnd!);
      final fitsRight = _chain.isEmpty || chosen.matches(_rightEnd!);
      final putLeft = fitsLeft && (!fitsRight || _rng.nextBool());
      _placeTile(p, chosen, onLeft: putLeft);
    });
  }

  void _finishRound({required int winner, required bool blocked}) {
    _botTimer?.cancel();
    final oppPips = List.generate(4, (p) => _hands[p].fold<int>(0, (s, d) => s + d.pips));
    final bonus = oppPips.fold<int>(0, (s, v) => s + v) - oppPips[winner];

    if (winner == 0) {
      _totalScore += bonus + (blocked ? 20 : 50);
      _saveBest(_totalScore);
      HapticFeedback.heavyImpact();
      _roundTitle = blocked ? 'MENANG BUNTU!' : 'GAPLE! KAMU MENANG!';
      _roundDetail = 'Sisa titik lawan: $bonus poin (+${blocked ? 20 : 50} bonus).\nTotal Skor: $_totalScore';
    } else {
      HapticFeedback.mediumImpact();
      _roundTitle = blocked ? 'PERMAINAN BUNTU' : '${_names[winner].toUpperCase()} MENANG';
      _roundDetail =
          '${_names[winner]} unggul (sisa ${oppPips[winner]} titik).\nSisa titikmu: ${oppPips[0]} • Total Skor: $_totalScore';
    }

    setState(() {
      _roundOver = true;
      _statusMsg = _roundTitle;
    });
  }

  void _onPlayerTapTile(_Domino tile) {
    if (_turn != 0 || _roundOver) return;
    if (!_canPlayTile(tile)) return;

    if (_chain.isEmpty) {
      _placeTile(0, tile, onLeft: false);
      return;
    }

    final fitsLeft = tile.matches(_leftEnd!);
    final fitsRight = tile.matches(_rightEnd!);

    if (fitsLeft && fitsRight && _leftEnd != _rightEnd) {
      setState(() => _pendingChoice = tile);
      return;
    }

    _placeTile(0, tile, onLeft: fitsLeft);
  }

  @override
  Widget build(BuildContext context) {
    final myPlayable = _turn == 0 && !_roundOver ? _playableTiles(0) : const <_Domino>[];

    return Scaffold(
      backgroundColor: const Color(0xFF071612),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B221B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'GAPLE ORI',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 17),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Ronde $_round  •  Skor $_totalScore',
                style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Main Baru',
            onPressed: () => _startRound(resetScore: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.0,
                colors: [Color(0xFF103A2D), Color(0xFF071612)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Opponents row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: [
                      Expanded(child: _BotBadge(name: _names[1], count: _hands[1].length, active: _turn == 1)),
                      const SizedBox(width: 8),
                      Expanded(child: _BotBadge(name: _names[2], count: _hands[2].length, active: _turn == 2)),
                      const SizedBox(width: 8),
                      Expanded(child: _BotBadge(name: _names[3], count: _hands[3].length, active: _turn == 3)),
                    ],
                  ),
                ),

                // Open ends & status bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.32)),
                    ),
                    child: Row(
                      children: [
                        _EndChip(label: 'KIRI', value: _leftEnd),
                        Expanded(
                          child: Text(
                            _statusMsg,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        _EndChip(label: 'KANAN', value: _rightEnd),
                      ],
                    ),
                  ),
                ),

                // Domino table chain
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.22), width: 1.4),
                    ),
                    child: _chain.isEmpty
                        ? const Center(
                            child: Text(
                              'Meja Gaple Kosong\nTap kartu di bawah untuk mulai',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                            ),
                          )
                        : Center(
                            child: SingleChildScrollView(
                              controller: _chainScroll,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < _chain.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                      child: _DominoTileWidget(
                                        a: _chain[i].left,
                                        b: _chain[i].right,
                                        horizontal: !_chain[i].isDouble,
                                        size: _chain[i].isDouble ? 34 : 32,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),

                // Choice bar (when tile fits both left & right) or Pass button
                if (_pendingChoice != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F5FF),
                              foregroundColor: const Color(0xFF071612),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _placeTile(0, _pendingChoice!, onLeft: true),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text('KIRI ($_leftEnd)', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD43B),
                              foregroundColor: const Color(0xFF071612),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _placeTile(0, _pendingChoice!, onLeft: false),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text('KANAN ($_rightEnd)', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_turn == 0 && !_roundOver && myPlayable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2D78),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _passTurn(0),
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('TIDAK ADA KARTU COCOK — LEWAT', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),

                // Player Hand
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1D17),
                    border: Border(top: BorderSide(color: const Color(0xFFFFD43B).withValues(alpha: 0.25))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _turn == 0 ? 'GILIRANMU (${_hands[0].length} kartu)' : 'KARTUMU (${_hands[0].length} kartu)',
                            style: TextStyle(
                              color: _turn == 0 ? const Color(0xFFFFD43B) : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Terbaik: $_bestScore',
                            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tile in _hands[0])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _onPlayerTapTile(tile),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    transform: Matrix4.translationValues(
                                      0,
                                      _pendingChoice == tile ? -10 : (myPlayable.contains(tile) ? -4 : 0),
                                      0,
                                    ),
                                    child: Opacity(
                                      opacity: _turn == 0 ? (myPlayable.contains(tile) ? 1.0 : 0.42) : 0.78,
                                      child: _DominoTileWidget(
                                        a: tile.a,
                                        b: tile.b,
                                        horizontal: false,
                                        size: 42,
                                        highlighted: myPlayable.contains(tile),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Round Over Overlay
          if (_roundOver)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C241D),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFFD43B), width: 1.6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _roundTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD43B),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _roundDetail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _startRound(resetScore: true),
                              child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD43B),
                                foregroundColor: const Color(0xFF071612),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                _round++;
                                _startRound(resetScore: false);
                              },
                              child: const Text('RONDE LANJUT', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
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

class _BotBadge extends StatelessWidget {
  const _BotBadge({required this.name, required this.count, required this.active});
  final String name;
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFD43B).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFFFFD43B) : Colors.white.withValues(alpha: 0.14),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: active ? const Color(0xFFFFD43B) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count kartu',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EndChip extends StatelessWidget {
  const _EndChip({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C23),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)),
          Text(
            value == null ? '-' : '$value',
            style: const TextStyle(color: Color(0xFFFFD43B), fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DominoTileWidget extends StatelessWidget {
  const _DominoTileWidget({
    required this.a,
    required this.b,
    required this.horizontal,
    required this.size,
    this.highlighted = false,
  });

  final int a;
  final int b;
  final bool horizontal;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final w = horizontal ? size * 2 : size;
    final h = horizontal ? size : size * 2;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF7), Color(0xFFEDE6D6)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? const Color(0xFFFFD43B) : const Color(0xFFCBBFA6),
          width: highlighted ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? const Color(0xFFFFD43B).withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: highlighted ? 10 : 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: horizontal
          ? Row(
              children: [
                Expanded(child: _PipFace(value: a)),
                Container(width: 1.5, height: size * 0.72, color: const Color(0xFFB5A486)),
                Expanded(child: _PipFace(value: b)),
              ],
            )
          : Column(
              children: [
                Expanded(child: _PipFace(value: a)),
                Container(height: 1.5, width: size * 0.72, color: const Color(0xFFB5A486)),
                Expanded(child: _PipFace(value: b)),
              ],
            ),
    );
  }
}

class _PipFace extends StatelessWidget {
  const _PipFace({required this.value});
  final int value;

  static Color _pipColor(int v) {
    switch (v) {
      case 1:
        return const Color(0xFFDC2626);
      case 2:
        return const Color(0xFF0284C7);
      case 3:
        return const Color(0xFF16A34A);
      case 4:
        return const Color(0xFFD97706);
      case 5:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF1E293B);
    }
  }

  static const Map<int, List<int>> _map = {
    0: [],
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final active = _map[value] ?? const [];
    final color = _pipColor(value);
    return Padding(
      padding: const EdgeInsets.all(4.5),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemBuilder: (_, idx) => active.contains(idx)
            ? Center(
                child: Container(
                  width: 6.2,
                  height: 6.2,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
