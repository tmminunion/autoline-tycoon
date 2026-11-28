import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BlockPiece {
  const _BlockPiece(this.cells, this.color);
  final List<Offset> cells; // (col, row) relative to (0,0)
  final Color color;

  int get width {
    int maxC = 0;
    for (final o in cells) {
      if (o.dx.toInt() > maxC) maxC = o.dx.toInt();
    }
    return maxC + 1;
  }

  int get height {
    int maxR = 0;
    for (final o in cells) {
      if (o.dy.toInt() > maxR) maxR = o.dy.toInt();
    }
    return maxR + 1;
  }
}

class NeonBlockScreen extends StatefulWidget {
  const NeonBlockScreen({super.key});

  @override
  State<NeonBlockScreen> createState() => _NeonBlockScreenState();
}

class _NeonBlockScreenState extends State<NeonBlockScreen> {
  static const int _gridSize = 8;
  static const double _boardPadding = 6.0;
  static const double _gridSpacing = 4.0;
  static const double _fingerLiftY = 72.0;
  static const String _bestKey = 'nufat_block_best_v1';

  static const List<Color> _palette = [
    Color(0xFF00F5FF), // cyan
    Color(0xFFFF2D78), // pink
    Color(0xFFFFD43B), // amber
    Color(0xFF39FF14), // neon green
    Color(0xFFA855F7), // purple
    Color(0xFFFF6B35), // orange
  ];

  static final List<List<Offset>> _shapes = [
    [const Offset(0, 0)],
    [const Offset(0, 0), const Offset(1, 0)],
    [const Offset(0, 0), const Offset(0, 1)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(2, 0)],
    [const Offset(0, 0), const Offset(0, 1), const Offset(0, 2)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(2, 0), const Offset(3, 0)],
    [const Offset(0, 0), const Offset(0, 1), const Offset(0, 2), const Offset(0, 3)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(0, 1), const Offset(1, 1)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(0, 1)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(1, 1)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(2, 0), const Offset(1, 1)],
    [const Offset(0, 0), const Offset(0, 1), const Offset(0, 2), const Offset(1, 2)],
    [const Offset(1, 0), const Offset(1, 1), const Offset(1, 2), const Offset(0, 2)],
    [const Offset(0, 0), const Offset(1, 0), const Offset(1, 1), const Offset(2, 1)],
    [
      const Offset(0, 0), const Offset(1, 0), const Offset(2, 0),
      const Offset(0, 1), const Offset(1, 1), const Offset(2, 1),
      const Offset(0, 2), const Offset(1, 2), const Offset(2, 2),
    ],
  ];

  final Random _rng = Random();
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  late List<List<Color?>> _board;
  late List<_BlockPiece?> _tray;
  int _score = 0;
  int _bestScore = 0;
  int _combo = 0;
  bool _gameOver = false;

  int? _dragIndex;
  Offset? _dragStackPos; // Local coordinates inside _stackKey (matches Positioned!)
  double _dragCellPx = 32.0; // Exact board cell size so floating block matches shadow 1:1
  int? _hoverRow;
  int? _hoverCol;
  bool _hoverValid = false;

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadBest();
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

  void _initGame() {
    _board = List.generate(_gridSize, (_) => List<Color?>.filled(_gridSize, null));
    _score = 0;
    _combo = 0;
    _gameOver = false;
    _dragIndex = null;
    _dragStackPos = null;
    _hoverRow = null;
    _hoverCol = null;
    _hoverValid = false;
    _refillTray();
  }

  void _refillTray() {
    _tray = List.generate(3, (_) {
      final shape = _shapes[_rng.nextInt(_shapes.length)];
      final color = _palette[_rng.nextInt(_palette.length)];
      return _BlockPiece(shape, color);
    });
    _checkGameOver();
  }

  bool _canPlace(_BlockPiece piece, int row, int col) {
    for (final o in piece.cells) {
      final r = row + o.dy.toInt();
      final c = col + o.dx.toInt();
      if (r < 0 || r >= _gridSize || c < 0 || c >= _gridSize) return false;
      if (_board[r][c] != null) return false;
    }
    return true;
  }

  bool _anyMoveAvailable() {
    for (final p in _tray) {
      if (p == null) continue;
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (_canPlace(p, r, c)) return true;
        }
      }
    }
    return false;
  }

  void _checkGameOver() {
    if (_tray.every((e) => e == null)) return;
    if (!_anyMoveAvailable()) {
      setState(() => _gameOver = true);
      HapticFeedback.heavyImpact();
      _saveBest(_score);
    }
  }

  void _updateHover(Offset globalPos) {
    if (_dragIndex == null) return;
    final piece = _tray[_dragIndex!];
    if (piece == null) return;

    final gridCtx = _gridKey.currentContext;
    final stackCtx = _stackKey.currentContext;
    if (gridCtx == null || stackCtx == null) return;
    final gridBox = gridCtx.findRenderObject() as RenderBox?;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    if (gridBox == null || !gridBox.hasSize || stackBox == null || !stackBox.hasSize) return;

    // Exact inner grid cell size & stride
    final innerSize = gridBox.size.width - _boardPadding * 2;
    final cellPx = (innerSize - _gridSpacing * (_gridSize - 1)) / _gridSize;
    final stride = cellPx + _gridSpacing;

    // Lift piece above finger so it remains clearly visible
    final liftedGlobal = globalPos - const Offset(0, _fingerLiftY);

    // Convert lifted pointer to BOTH grid-local and stack-local coordinates
    final gridLocal = gridBox.globalToLocal(liftedGlobal);
    final stackLocal = stackBox.globalToLocal(liftedGlobal);

    final pieceW = piece.width * cellPx + (piece.width - 1) * _gridSpacing;
    final pieceH = piece.height * cellPx + (piece.height - 1) * _gridSpacing;

    final col = ((gridLocal.dx - _boardPadding - pieceW / 2) / stride).round();
    final row = ((gridLocal.dy - _boardPadding - pieceH / 2) / stride).round();

    final valid = _canPlace(piece, row, col);
    final nearBoard = row >= -1 && row < _gridSize && col >= -1 && col < _gridSize;

    // When valid, gently snap floating piece center to the exact ghost cell center
    Offset finalStackPos = stackLocal;
    if (nearBoard && valid) {
      final snappedGridCenter = Offset(
        _boardPadding + col * stride + pieceW / 2,
        _boardPadding + row * stride + pieceH / 2,
      );
      final snappedGlobal = gridBox.localToGlobal(snappedGridCenter);
      finalStackPos = stackBox.globalToLocal(snappedGlobal);
    }

    setState(() {
      _dragCellPx = cellPx;
      _dragStackPos = finalStackPos;
      if (nearBoard) {
        _hoverRow = row;
        _hoverCol = col;
        _hoverValid = valid;
      } else {
        _hoverRow = null;
        _hoverCol = null;
        _hoverValid = false;
      }
    });
  }

  void _endDrag() {
    if (_dragIndex == null) return;
    final idx = _dragIndex!;
    final piece = _tray[idx];

    if (piece != null && _hoverRow != null && _hoverCol != null && _hoverValid) {
      HapticFeedback.mediumImpact();
      for (final o in piece.cells) {
        _board[_hoverRow! + o.dy.toInt()][_hoverCol! + o.dx.toInt()] = piece.color;
      }
      _tray[idx] = null;
      int gained = piece.cells.length * 10;

      final fullRows = <int>[];
      final fullCols = <int>[];
      for (int r = 0; r < _gridSize; r++) {
        if (_board[r].every((c) => c != null)) fullRows.add(r);
      }
      for (int c = 0; c < _gridSize; c++) {
        bool full = true;
        for (int r = 0; r < _gridSize; r++) {
          if (_board[r][c] == null) {
            full = false;
            break;
          }
        }
        if (full) fullCols.add(c);
      }

      final clearedLines = fullRows.length + fullCols.length;
      if (clearedLines > 0) {
        _combo++;
        HapticFeedback.heavyImpact();
        for (final r in fullRows) {
          for (int c = 0; c < _gridSize; c++) {
            _board[r][c] = null;
          }
        }
        for (final c in fullCols) {
          for (int r = 0; r < _gridSize; r++) {
            _board[r][c] = null;
          }
        }
        gained += clearedLines * 100 * _combo;
      } else {
        _combo = 0;
      }

      _score += gained;
      if (_score > _bestScore) _saveBest(_score);

      setState(() {
        _dragIndex = null;
        _dragStackPos = null;
        _hoverRow = null;
        _hoverCol = null;
        _hoverValid = false;
      });

      if (_tray.every((e) => e == null)) {
        _refillTray();
      } else {
        _checkGameOver();
      }
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _dragIndex = null;
        _dragStackPos = null;
        _hoverRow = null;
        _hoverCol = null;
        _hoverValid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draggedPiece = _dragIndex != null ? _tray[_dragIndex!] : null;
    final draggedW = draggedPiece == null
        ? 0.0
        : draggedPiece.width * _dragCellPx + (draggedPiece.width - 1) * _gridSpacing;
    final draggedH = draggedPiece == null
        ? 0.0
        : draggedPiece.height * _dragCellPx + (draggedPiece.height - 1) * _gridSpacing;

    return Scaffold(
      backgroundColor: const Color(0xFF070814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'NEON BLOCK',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Ulangi',
            onPressed: () => setState(_initGame),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        key: _stackKey,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ScorePill(
                          label: 'SKOR',
                          value: '$_score',
                          accent: const Color(0xFF00F5FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScorePill(
                          label: 'TERBAIK',
                          value: '$_bestScore',
                          accent: const Color(0xFFFFD43B),
                        ),
                      ),
                    ],
                  ),
                  if (_combo > 1) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD43B).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFFFD43B)),
                      ),
                      child: Text(
                        '${_combo}x COMBO STREAK!',
                        style: const TextStyle(
                          color: Color(0xFFFFD43B),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          key: _gridKey,
                          padding: const EdgeInsets.all(_boardPadding),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1226),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF23294D), width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F5FF).withValues(alpha: 0.10),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _gridSize * _gridSize,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _gridSize,
                              crossAxisSpacing: _gridSpacing,
                              mainAxisSpacing: _gridSpacing,
                            ),
                            itemBuilder: (_, idx) {
                              final r = idx ~/ _gridSize;
                              final c = idx % _gridSize;
                              final cellColor = _board[r][c];
                              final isPreview = _isPreviewCell(r, c);
                              final previewColor = draggedPiece?.color ?? Colors.white;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 90),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: cellColor ??
                                      (isPreview
                                          ? (_hoverValid
                                              ? previewColor.withValues(alpha: 0.36)
                                              : const Color(0xFFFF2D78).withValues(alpha: 0.28))
                                          : const Color(0xFF171C36)),
                                  border: Border.all(
                                    color: cellColor != null
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : isPreview
                                            ? (_hoverValid ? previewColor : const Color(0xFFFF2D78))
                                            : const Color(0xFF23294D),
                                    width: isPreview ? 1.5 : 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 108,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (i) {
                        final piece = _tray[i];
                        final hidden = _dragIndex == i || piece == null;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: piece == null
                                ? null
                                : (d) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _dragIndex = i);
                                    _updateHover(d.globalPosition);
                                  },
                            onPanUpdate: (d) => _updateHover(d.globalPosition),
                            onPanEnd: (_) => _endDrag(),
                            onPanCancel: _endDrag,
                            child: Center(
                              child: Opacity(
                                opacity: hidden ? 0.12 : 1.0,
                                child: piece == null
                                    ? const SizedBox.shrink()
                                    : _PiecePreview(piece: piece, cellSize: 19, gap: 2.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (draggedPiece != null && _dragStackPos != null)
            Positioned(
              left: _dragStackPos!.dx - draggedW / 2,
              top: _dragStackPos!.dy - draggedH / 2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _hoverValid ? 0.94 : 0.78,
                  child: _PiecePreview(
                    piece: draggedPiece,
                    cellSize: _dragCellPx,
                    gap: _gridSpacing,
                  ),
                ),
              ),
            ),
          if (_gameOver)
            Container(
              color: Colors.black.withValues(alpha: 0.82),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(28),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10132A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF00F5FF).withValues(alpha: 0.45)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          color: Color(0xFFFF2D78),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Skor Akhir: $_score\nSkor Terbaik: $_bestScore',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F5FF),
                          foregroundColor: const Color(0xFF070814),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => setState(_initGame),
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

  bool _isPreviewCell(int r, int c) {
    if (_dragIndex == null || _hoverRow == null || _hoverCol == null) return false;
    final piece = _tray[_dragIndex!];
    if (piece == null) return false;
    for (final o in piece.cells) {
      if (_hoverRow! + o.dy.toInt() == r && _hoverCol! + o.dx.toInt() == c) {
        return true;
      }
    }
    return false;
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10132A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800)),
          Text(value, style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PiecePreview extends StatelessWidget {
  const _PiecePreview({
    required this.piece,
    required this.cellSize,
    required this.gap,
  });
  final _BlockPiece piece;
  final double cellSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final w = piece.width * cellSize + (piece.width - 1) * gap;
    final h = piece.height * cellSize + (piece.height - 1) * gap;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (final o in piece.cells)
            Positioned(
              left: o.dx * (cellSize + gap),
              top: o.dy * (cellSize + gap),
              width: cellSize,
              height: cellSize,
              child: Container(
                decoration: BoxDecoration(
                  color: piece.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: piece.color.withValues(alpha: 0.45), blurRadius: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
