import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chess_engine.dart';

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  static const String _bestKey = 'nufat_chess_best_v1';
  static const Color _bg = Color(0xFF140F08);
  static const Color _gold = Color(0xFFC9993A);
  static const Color _goldLight = Color(0xFFE8C46A);
  static const Color _sqLight = Color(0xFFF0D9B5);
  static const Color _sqDark = Color(0xFFB58863);

  final ChessEngine _engine = ChessEngine();
  ChessMode _mode = ChessMode.easy;
  List<int>? _selected;
  List<ChessMove> _hints = [];
  bool _aiThinking = false;
  bool _gameOver = false;
  int _bestScore = 0;
  int _sessionScore = 0;
  String _statusText = 'Mulai Permainan';

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _bestScore = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _recordWinScore() async {
    final gain = _mode == ChessMode.pro ? 1000 : 500;
    _sessionScore += gain;
    if (_sessionScore > _bestScore) {
      _bestScore = _sessionScore;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_bestKey, _bestScore);
      } catch (_) {}
    }
  }

  void _setMode(ChessMode m) {
    if (_aiThinking) return;
    setState(() {
      _mode = m;
    });
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _engine.reset();
      _selected = null;
      _hints = [];
      _aiThinking = false;
      _gameOver = false;
      _statusText = 'Mulai Permainan';
    });
  }

  void _undo() {
    if (_aiThinking || _engine.history.isEmpty) return;
    final steps = (_mode != ChessMode.pvp && _engine.history.length >= 2) ? 2 : 1;
    setState(() {
      _engine.undo(steps: steps);
      _selected = null;
      _hints = [];
      _gameOver = false;
      _refreshStatus(showDialogIfEnded: false);
    });
  }

  Future<void> _onCellTap(int r, int c) async {
    if (_aiThinking || _gameOver) return;
    if (_mode != ChessMode.pvp && _engine.turn == 'b') return;

    if (_selected != null) {
      ChessMove? chosen;
      for (final h in _hints) {
        if (h.tr == r && h.tc == c) {
          chosen = h;
          break;
        }
      }
      if (chosen != null) {
        await _executeMove(chosen);
        return;
      }
    }

    final p = _engine.board[r][c];
    if (p != null && p[0] == _engine.turn) {
      setState(() {
        _selected = [r, c];
        _hints = _engine.getLegalMoves(r, c);
      });
    } else {
      setState(() {
        _selected = null;
        _hints = [];
      });
    }
  }

  Future<void> _executeMove(ChessMove m) async {
    String promo = 'Q';
    if (m.extra == 'promo' && (_mode == ChessMode.pvp || _engine.turn == 'w')) {
      final picked = await _askPromotion(_engine.turn);
      if (picked != null) promo = picked;
    }

    setState(() {
      _engine.commitMove(m, promotionPiece: promo);
      _selected = null;
      _hints = [];
    });

    _refreshStatus(showDialogIfEnded: true);

    if (!_gameOver && _mode != ChessMode.pvp && _engine.turn == 'b') {
      await _runAiTurn();
    }
  }

  Future<void> _runAiTurn() async {
    setState(() {
      _aiThinking = true;
      _statusText = '🤖 AI sedang berpikir...';
    });

    await Future<void>.delayed(Duration(milliseconds: _mode == ChessMode.pro ? 220 : 180));
    final payload = <String, dynamic>{
      'board': _engine.board.map((r) => List<String?>.from(r)).toList(),
      'turn': _engine.turn,
      'castleRights': Map<String, bool>.from(_engine.castleRights),
      'enPassant': _engine.enPassant == null ? null : List<int>.from(_engine.enPassant!),
      'mode': _mode.index,
    };

    final move = await compute(computeChessAiIsolate, payload);
    if (!mounted) return;

    setState(() {
      _aiThinking = false;
      if (move != null) {
        _engine.commitMove(move, promotionPiece: 'Q');
      }
    });
    _refreshStatus(showDialogIfEnded: true);
  }

  void _refreshStatus({required bool showDialogIfEnded}) {
    final inCheck = _engine.isInCheck(_engine.turn);
    final legal = _engine.getAllLegal(_engine.turn);

    if (legal.isEmpty) {
      _gameOver = true;
      if (inCheck) {
        String winner;
        if (_mode == ChessMode.pvp) {
          winner = _engine.turn == 'w' ? 'Hitam Menang!' : 'Putih Menang!';
        } else if (_engine.turn == 'w') {
          winner = 'AI Menang 🤖';
        } else {
          winner = 'Kamu Menang 🎉';
          _recordWinScore();
        }
        _statusText = 'Skakmat!';
        if (showDialogIfEnded) _showGameOverDialog('Skakmat!', winner);
      } else {
        _statusText = 'Seri (Stalemate)';
        if (showDialogIfEnded) _showGameOverDialog('Seri! 🤝', 'Stalemate — tidak ada langkah legal.');
      }
    } else if (inCheck) {
      _statusText = '⚠ Skak!';
    } else {
      _statusText = '';
    }
    if (mounted) setState(() {});
  }

  Future<String?> _askPromotion(String color) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23160A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _gold, width: 1.5),
        ),
        title: const Text(
          'Promosi Pion',
          textAlign: TextAlign.center,
          style: TextStyle(color: _goldLight, fontWeight: FontWeight.w900),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final t in const ['Q', 'R', 'B', 'N'])
              InkWell(
                onTap: () => Navigator.of(ctx).pop(t),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    ChessEngine.pieceSymbols['$color$t'] ?? t,
                    style: const TextStyle(fontSize: 30, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showGameOverDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23160A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _gold, width: 1.5),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _goldLight, fontWeight: FontWeight.w900, fontSize: 22),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFF5EDD6), fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _bg),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Main Lagi', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _engine.history.isNotEmpty ? _engine.history.last : null;
    final topLabel = _mode == ChessMode.pvp
        ? 'Hitam'
        : (_mode == ChessMode.pro ? '💀 Pro AI (Hitam)' : '🤖 Easy AI (Hitam)');
    final botLabel = _mode == ChessMode.pvp ? 'Putih' : '♟ Kamu (Putih)';
    final turnLabel = _mode == ChessMode.pvp
        ? (_engine.turn == 'w' ? 'Putih Jalan' : 'Hitam Jalan')
        : (_engine.turn == 'w' ? 'Giliran Kamu ♟' : 'AI Berpikir 🤖');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              // Compact Aesthetic Header
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF24160A), Color(0xFF140F08)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(bottom: BorderSide(color: _gold.withValues(alpha: 0.35))),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _gold.withValues(alpha: 0.18),
                        border: Border.all(color: _gold.withValues(alpha: 0.5)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('♟️', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CATUR ORI',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _goldLight, letterSpacing: 0.5),
                          ),
                          Text(
                            'Native Offline · Minimax AI',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD6B980)),
                          ),
                        ],
                      ),
                    ),
                    if (_bestScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _gold.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 13, color: _goldLight),
                            const SizedBox(width: 4),
                            Text(
                              '$_bestScore',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _goldLight),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      // Mode Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _gold.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          children: [
                            _ModeTab(label: '🤖 Easy AI', active: _mode == ChessMode.easy, onTap: () => _setMode(ChessMode.easy)),
                            _ModeTab(label: '💀 Pro AI', active: _mode == ChessMode.pro, onTap: () => _setMode(ChessMode.pro)),
                            _ModeTab(label: '👥 2 Pemain', active: _mode == ChessMode.pvp, onTap: () => _setMode(ChessMode.pvp)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Turn & Status Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _gold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _engine.turn == 'w' ? const Color(0xFFF5EDD6) : const Color(0xFF1A1208),
                                    border: Border.all(color: _gold, width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  turnLabel,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF5EDD6)),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _statusText,
                            style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: _goldLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Top Player + Captured
                      _PlayerRow(
                        label: topLabel,
                        captured: _engine.capturedB.map((p) => ChessEngine.pieceSymbols['b$p'] ?? '').join(' '),
                      ),

                      // Board
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3D1F00), Color(0xFF1A1208)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: _gold, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 64,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                                itemBuilder: (_, idx) {
                                  final r = idx ~/ 8;
                                  final c = idx % 8;
                                  final isLight = (r + c) % 2 == 0;
                                  final isSelected = _selected != null && _selected![0] == r && _selected![1] == c;
                                  final isLast = last != null &&
                                      ((last.fr == r && last.fc == c) || (last.tr == r && last.tc == c));
                                  final isHint = _hints.any((h) => h.tr == r && h.tc == c);
                                  final piece = _engine.board[r][c];
                                  final isWhitePiece = piece != null && piece[0] == 'w';

                                  Color bgColor = isLight ? _sqLight : _sqDark;
                                  if (isLast) bgColor = Color.lerp(bgColor, const Color(0xFFCDD91A), 0.55)!;
                                  if (isSelected) bgColor = Color.lerp(bgColor, const Color(0xFF4ADE80), 0.55)!;

                                  return GestureDetector(
                                    onTap: () => _onCellTap(r, c),
                                    child: Container(
                                      color: bgColor,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (isHint && piece == null)
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.25),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          if (isHint && piece != null)
                                            Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.85), width: 3),
                                              ),
                                            ),
                                          if (piece != null)
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                ChessEngine.pieceSymbols[piece] ?? '',
                                                style: TextStyle(
                                                  fontSize: 30,
                                                  height: 1,
                                                  color: isWhitePiece ? Colors.white : const Color(0xFF141414),
                                                  shadows: isWhitePiece
                                                      ? const [
                                                          Shadow(color: Color(0xDD000000), blurRadius: 3, offset: Offset(0, 1)),
                                                          Shadow(color: Color(0xAA000000), blurRadius: 1, offset: Offset(0.6, 0.6)),
                                                        ]
                                                      : const [
                                                          Shadow(color: Color(0x44FFFFFF), blurRadius: 2),
                                                        ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom Player + Captured
                      _PlayerRow(
                        label: botLabel,
                        captured: _engine.capturedW.map((p) => ChessEngine.pieceSymbols['w$p'] ?? '').join(' '),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Controls
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _goldLight,
                                side: const BorderSide(color: _gold),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _aiThinking ? null : _resetGame,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _goldLight,
                                side: const BorderSide(color: _gold),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: (_aiThinking || _engine.history.isEmpty) ? null : _undo,
                              icon: const Icon(Icons.undo_rounded, size: 18),
                              label: const Text('Undo', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFC9993A) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF140F08) : const Color(0xFFF5EDD6).withValues(alpha: 0.78),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.label, required this.captured});

  final String label;
  final String captured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFE8C46A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              captured,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Color(0xFFF5EDD6)),
            ),
          ),
        ],
      ),
    );
  }
}
