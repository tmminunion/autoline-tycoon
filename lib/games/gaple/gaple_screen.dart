import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/game_orientation.dart';

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
  bool _landscapeLocked = true;
  String _statusMsg = 'Giliran dimulai...';
  _Domino? _pendingChoice;
  bool _roundOver = false;
  String _roundTitle = '';
  String _roundDetail = '';
  Timer? _botTimer;

  @override
  void initState() {
    super.initState();
    GameOrientation.lockLandscape();
    _loadBest();
    _startRound(resetScore: true);
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _chainScroll.dispose();
    GameOrientation.lockPortrait();
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() => _landscapeLocked = !_landscapeLocked);
    if (_landscapeLocked) {
      GameOrientation.lockLandscape();
    } else {
      GameOrientation.lockPortrait();
    }
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
    _statusMsg = '${_names[player]} LEWAT';

    if (_consecutivePasses >= 4) {
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
    _botTimer = Timer(const Duration(milliseconds: 560), () {
      if (!mounted || _roundOver || _turn == 0) return;
      final p = _turn;
      final playable = _playableTiles(p);
      if (playable.isEmpty) {
        _passTurn(p);
        return;
      }

      _Domino chosen;
      if (_chain.isEmpty && playable.any((d) => d.a == 6 && d.b == 6)) {
        chosen = playable.firstWhere((d) => d.a == 6 && d.b == 6);
      } else {
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
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF061510),
      body: Stack(
        children: [
          // Deep casino/warung emerald felt table background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.05,
                colors: [Color(0xFF14533C), Color(0xFF0A2B1F), Color(0xFF05140E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Sleek Table Header HUD
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      _TableIconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GAPLE ORI',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4A24C).withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            _statusMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'R$_round • $_totalScore',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TableIconBtn(
                        icon: Icons.screen_rotation_rounded,
                        tooltip: 'Putar Layar',
                        onTap: _toggleOrientation,
                      ),
                      const SizedBox(width: 6),
                      _TableIconBtn(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Main Baru',
                        onTap: () => _startRound(resetScore: true),
                      ),
                    ],
                  ),
                ),

                // Main Table Area (4-sided seating in landscape, compact top bots in portrait)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: isLandscape
                        ? Column(
                            children: [
                              _BotSeat(name: _names[2], count: _hands[2].length, active: _turn == 2, compact: true),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Row(
                                  children: [
                                    _BotSeat(name: _names[1], count: _hands[1].length, active: _turn == 1, vertical: true),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildFeltBoard()),
                                    const SizedBox(width: 8),
                                    _BotSeat(name: _names[3], count: _hands[3].length, active: _turn == 3, vertical: true),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _BotSeat(name: _names[1], count: _hands[1].length, active: _turn == 1)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _BotSeat(name: _names[2], count: _hands[2].length, active: _turn == 2)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _BotSeat(name: _names[3], count: _hands[3].length, active: _turn == 3)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(child: _buildFeltBoard()),
                            ],
                          ),
                  ),
                ),

                // Player Hand Dock
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(12, isLandscape ? 6 : 10, 12, isLandscape ? 8 : 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0A241B), Color(0xFF061611)],
                    ),
                    border: Border(top: BorderSide(color: const Color(0xFFD4A24C).withValues(alpha: 0.35))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: isLandscape ? 104 : 88,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _turn == 0 ? 'GILIRANMU' : 'KARTUMU',
                              style: TextStyle(
                                color: _turn == 0 ? const Color(0xFFFDE68A) : Colors.white54,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              '${_hands[0].length} kartu • Best $_bestScore',
                              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                            ),
                            if (_turn == 0 && !_roundOver && myPlayable.isEmpty) ...[
                              const SizedBox(height: 5),
                              GestureDetector(
                                onTap: () => _passTurn(0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFE2C55),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Text(
                                    'LEWAT ⏭',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
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
                                        _pendingChoice == tile ? -8 : (myPlayable.contains(tile) ? -3 : 0),
                                        0,
                                      ),
                                      child: Opacity(
                                        opacity: _turn == 0 ? (myPlayable.contains(tile) ? 1.0 : 0.4) : 0.78,
                                        child: _DominoTileWidget(
                                          a: tile.a,
                                          b: tile.b,
                                          horizontal: false,
                                          size: isLandscape ? 32 : 38,
                                          highlighted: myPlayable.contains(tile),
                                        ),
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
              ],
            ),
          ),

          // Round Over Modal
          if (_roundOver)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C261E),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD4A24C), width: 1.8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _roundTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _roundDetail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _startRound(resetScore: true),
                              child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: const Color(0xFF071612),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildFeltBoard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF176045), Color(0xFF0C3828)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6B3E1E), width: 4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 18),
        ],
      ),
      child: Stack(
        children: [
          // Open end indicators
          Positioned(
            top: 8,
            left: 10,
            child: _EndChip(label: 'KIRI', value: _leftEnd),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: _EndChip(label: 'KANAN', value: _rightEnd),
          ),
          // Domino chain
          Center(
            child: _chain.isEmpty
                ? const Text(
                    'Meja Gaple Siap\nTap kartu di bawah untuk memasang',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                  )
                : SingleChildScrollView(
                    controller: _chainScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _chain.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.2),
                            child: _DominoTileWidget(
                              a: _chain[i].left,
                              b: _chain[i].right,
                              horizontal: !_chain[i].isDouble,
                              size: _chain[i].isDouble ? 30 : 28,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          // Choice overlay when tile fits both ends
          if (_pendingChoice != null)
            Positioned(
              bottom: 8,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF061510),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _placeTile(0, _pendingChoice!, onLeft: true),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text('PASANG KIRI ($_leftEnd)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF061510),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _placeTile(0, _pendingChoice!, onLeft: false),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text('PASANG KANAN ($_rightEnd)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TableIconBtn extends StatelessWidget {
  const _TableIconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _BotSeat extends StatelessWidget {
  const _BotSeat({
    required this.name,
    required this.count,
    required this.active,
    this.compact = false,
    this.vertical = false,
  });

  final String name;
  final int count;
  final bool active;
  final bool compact;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final shownCards = min(count, 7);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: vertical ? 78 : null,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 8, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF59E0B).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFFF59E0B) : Colors.white12,
          width: active ? 1.6 : 1,
        ),
      ),
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: active ? const Color(0xFFFDE68A) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    shownCards,
                    (_) => Container(
                      width: 8,
                      height: 13,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFD4A24C).withValues(alpha: 0.55), width: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? const Color(0xFFFDE68A) : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    shownCards,
                    (_) => Container(
                      width: 7,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFD4A24C).withValues(alpha: 0.5), width: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$count kartu', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4A24C).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w800)),
          Text(
            value == null ? '-' : '$value',
            style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5, fontWeight: FontWeight.w900),
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
          colors: [Color(0xFFFFFEF9), Color(0xFFF1E9D8), Color(0xFFE2D6BE)],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: highlighted ? const Color(0xFFFBBF24) : const Color(0xFFB5A486),
          width: highlighted ? 2.1 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? const Color(0xFFFBBF24).withValues(alpha: 0.48)
                : Colors.black.withValues(alpha: 0.45),
            blurRadius: highlighted ? 10 : 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          horizontal
              ? Row(
                  children: [
                    Expanded(child: _PipFace(value: a)),
                    Container(width: 1.4, height: size * 0.72, color: const Color(0xFFA89677)),
                    Expanded(child: _PipFace(value: b)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _PipFace(value: a)),
                    Container(height: 1.4, width: size * 0.72, color: const Color(0xFFA89677)),
                    Expanded(child: _PipFace(value: b)),
                  ],
                ),
          // Authentic brass center spinner pin
          Container(
            width: 3.8,
            height: 3.8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD4A24C),
            ),
          ),
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
        return const Color(0xFF15803D);
      case 4:
        return const Color(0xFFD97706);
      case 5:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0F172A);
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
      padding: const EdgeInsets.all(3.8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemBuilder: (_, idx) => active.contains(idx)
            ? Center(
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 1, offset: Offset(0, 0.5)),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
