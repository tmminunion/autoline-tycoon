import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DamPiece {
  _DamPiece({required this.isPlayer, this.isKing = false});
  final bool isPlayer;
  bool isKing;
}

class _DamMove {
  const _DamMove(this.fr, this.fc, this.tr, this.tc, {this.capR, this.capC});
  final int fr;
  final int fc;
  final int tr;
  final int tc;
  final int? capR;
  final int? capC;
  bool get isCapture => capR != null;
}

class DamScreen extends StatefulWidget {
  const DamScreen({super.key});

  @override
  State<DamScreen> createState() => _DamScreenState();
}

class _DamScreenState extends State<DamScreen> {
  static const String _bestKey = 'nufat_dam_best_v1';
  late List<List<_DamPiece?>> _board;
  bool _playerTurn = true;
  bool _vsAi = true;
  bool _gameOver = false;
  int _wins = 0;
  int? _selR;
  int? _selC;
  List<_DamMove> _validMoves = const [];
  String _status = 'Giliranmu (Merah)! Pilih bidak.';
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadBest();
    _reset();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _wins = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveWins(int v) async {
    _wins = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, v);
    } catch (_) {}
  }

  void _reset() {
    _board = List.generate(8, (_) => List<_DamPiece?>.filled(8, null));
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c).isOdd) _board[r][c] = _DamPiece(isPlayer: false);
      }
    }
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c).isOdd) _board[r][c] = _DamPiece(isPlayer: true);
      }
    }
    setState(() {
      _playerTurn = true;
      _gameOver = false;
      _selR = null;
      _selC = null;
      _validMoves = const [];
      _status = 'Giliranmu (Merah)! Pilih bidak.';
    });
  }

  List<_DamMove> _movesForPiece(int r, int c) {
    final p = _board[r][c];
    if (p == null) return const [];
    final dirs = p.isKing
        ? const [[-1, -1], [-1, 1], [1, -1], [1, 1]]
        : (p.isPlayer ? const [[-1, -1], [-1, 1]] : const [[1, -1], [1, 1]]);
    final caps = <_DamMove>[];
    final steps = <_DamMove>[];

    for (final d in dirs) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      if (_board[nr][nc] == null) {
        steps.add(_DamMove(r, c, nr, nc));
      } else if (_board[nr][nc]!.isPlayer != p.isPlayer) {
        final jr = nr + d[0];
        final jc = nc + d[1];
        if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8 && _board[jr][jc] == null) {
          caps.add(_DamMove(r, c, jr, jc, capR: nr, capC: nc));
        }
      }
    }
    return caps.isNotEmpty ? caps : steps;
  }

  List<_DamMove> _allMoves(bool forPlayer) {
    final caps = <_DamMove>[];
    final steps = <_DamMove>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = _board[r][c];
        if (p != null && p.isPlayer == forPlayer) {
          for (final m in _movesForPiece(r, c)) {
            if (m.isCapture) {
              caps.add(m);
            } else {
              steps.add(m);
            }
          }
        }
      }
    }
    return caps.isNotEmpty ? caps : steps;
  }

  void _onTapCell(int r, int c) {
    if (_gameOver || (!_playerTurn && _vsAi)) return;

    // Execute if tapped a valid destination
    for (final m in _validMoves) {
      if (m.tr == r && m.tc == c) {
        _applyMove(m);
        return;
      }
    }

    final p = _board[r][c];
    if (p != null && p.isPlayer == _playerTurn) {
      final all = _allMoves(_playerTurn);
      final pieceMoves = all.where((m) => m.fr == r && m.fc == c).toList();
      setState(() {
        _selR = r;
        _selC = c;
        _validMoves = pieceMoves;
      });
    }
  }

  void _applyMove(_DamMove m) {
    final piece = _board[m.fr][m.fc]!;
    _board[m.fr][m.fc] = null;
    _board[m.tr][m.tc] = piece;

    if (m.isCapture) {
      _board[m.capR!][m.capC!] = null;
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    if (piece.isPlayer && m.tr == 0) piece.isKing = true;
    if (!piece.isPlayer && m.tr == 7) piece.isKing = true;

    // Check multi-jump if captured
    if (m.isCapture) {
      final nextCaps = _movesForPiece(m.tr, m.tc).where((x) => x.isCapture).toList();
      if (nextCaps.isNotEmpty) {
        setState(() {
          _selR = m.tr;
          _selC = m.tc;
          _validMoves = nextCaps;
          _status = 'Lompat berantai tersedia!';
        });
        if (!_playerTurn && _vsAi) {
          Future<void>.delayed(const Duration(milliseconds: 420), () {
            if (mounted && !_gameOver) _applyMove(nextCaps.first);
          });
        }
        return;
      }
    }

    final nextTurn = !_playerTurn;
    final nextMoves = _allMoves(nextTurn);
    if (nextMoves.isEmpty) {
      final playerWon = _playerTurn;
      if (playerWon) _saveWins(_wins + 1);
      setState(() {
        _selR = null;
        _selC = null;
        _validMoves = const [];
        _gameOver = true;
        _status = playerWon ? 'KAMU MENANG DAM-DAMAN!' : '${_vsAi ? "BOT AI" : "PUTIH"} MENANG!';
      });
      return;
    }

    setState(() {
      _playerTurn = nextTurn;
      _selR = null;
      _selC = null;
      _validMoves = const [];
      _status = _playerTurn ? 'Giliranmu (Merah)!' : 'Giliran ${_vsAi ? "Bot AI" : "Putih"}...';
    });

    if (!_playerTurn && _vsAi) {
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (!mounted || _gameOver || _playerTurn) return;
        final aiMoves = _allMoves(false);
        if (aiMoves.isEmpty) return;
        aiMoves.shuffle(_rng);
        // Prefer captures or kinging
        aiMoves.sort((a, b) => (b.isCapture ? 2 : 0).compareTo(a.isCapture ? 2 : 0));
        _applyMove(aiMoves.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130B0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF211310),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('DAM-DAMAN ORI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _vsAi = !_vsAi);
              _reset();
            },
            child: Text(_vsAi ? 'vs AI' : '2P', style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: _reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('Menang: $_wins', style: const TextStyle(color: Color(0xFFFFD43B), fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD9A441), width: 2.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 64,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                          itemBuilder: (_, idx) {
                            final r = idx ~/ 8;
                            final c = idx % 8;
                            final dark = (r + c).isOdd;
                            final p = _board[r][c];
                            final isSel = _selR == r && _selC == c;
                            final isDest = _validMoves.any((m) => m.tr == r && m.tc == c);

                            return GestureDetector(
                              onTap: () => _onTapCell(r, c),
                              child: Container(
                                color: isSel
                                    ? const Color(0xFF78350F)
                                    : (dark ? const Color(0xFF3E2216) : const Color(0xFFE7D3B3)),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isDest)
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD43B).withValues(alpha: 0.75),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    if (p != null)
                                      Container(
                                        margin: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: p.isPlayer
                                                ? [const Color(0xFFFF5C8A), const Color(0xFF991B1B)]
                                                : [const Color(0xFFFFFDF7), const Color(0xFFD6C7AE)],
                                          ),
                                          border: Border.all(color: const Color(0xFFFFD43B), width: p.isKing ? 2.4 : 1.2),
                                        ),
                                        child: p.isKing
                                            ? const Center(child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD43B), size: 18))
                                            : null,
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
              ),
              if (_gameOver) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD43B), foregroundColor: Colors.black),
                  onPressed: _reset,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('MAIN LAGI', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
