import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/sound_service.dart';

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
  static const double _boardPadding = 7.0;
  static const double _gridSpacing = 4.5;
  static const double _fingerLiftY = 74.0;
  static const String _bestKey = 'nufat_block_best_v1';

  // Vibrant 3D Neon Glass palette inspired by modern crystal neon blocks
  static const List<Color> _palette = [
    Color(0xFF00E5FF), // electric cyan
    Color(0xFF3B82F6), // royal neon blue
    Color(0xFFE024FF), // neon magenta
    Color(0xFFFFB800), // luminous amber
    Color(0xFF10F587), // neon emerald
    Color(0xFFFF3B6B), // neon coral rose
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
  final SoundService _sfx = SoundService();

  late List<List<Color?>> _board;
  late List<_BlockPiece?> _tray;
  int _score = 0;
  int _bestScore = 0;
  int _combo = 0;
  bool _gameOver = false;
  bool _muted = false;

  // Drag & snap state
  int? _dragIndex;
  Offset? _dragStackPos;
  double _dragCellPx = 34.0;
  int? _hoverRow;
  int? _hoverCol;
  bool _hoverValid = false;

  // Line-clear hold & burst animation state
  bool _isClearing = false;
  Set<int> _clearingCells = <int>{};
  int _clearingPhase = 0; // 0 = none, 1 = hold & glow pulse, 2 = shrink & fade out
  String? _clearBannerText;

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadBest();
  }

  @override
  void dispose() {
    _sfx.dispose();
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
    _isClearing = false;
    _clearingCells = <int>{};
    _clearingPhase = 0;
    _clearBannerText = null;
    _refillTray();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _sfx.isMuted = _muted;
    });
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
      _sfx.playExplosion(heavy: true);
      _saveBest(_score);
    }
  }

  /// Computes cells that would clear if the currently hovered valid piece is dropped.
  Set<int> _computeWillClearPreview() {
    if (_dragIndex == null || !_hoverValid || _hoverRow == null || _hoverCol == null) {
      return const <int>{};
    }
    final piece = _tray[_dragIndex!];
    if (piece == null) return const <int>{};

    final placed = <int>{};
    for (final o in piece.cells) {
      placed.add((_hoverRow! + o.dy.toInt()) * _gridSize + (_hoverCol! + o.dx.toInt()));
    }

    final result = <int>{};
    for (int r = 0; r < _gridSize; r++) {
      bool full = true;
      for (int c = 0; c < _gridSize; c++) {
        if (_board[r][c] == null && !placed.contains(r * _gridSize + c)) {
          full = false;
          break;
        }
      }
      if (full) {
        for (int c = 0; c < _gridSize; c++) {
          result.add(r * _gridSize + c);
        }
      }
    }
    for (int c = 0; c < _gridSize; c++) {
      bool full = true;
      for (int r = 0; r < _gridSize; r++) {
        if (_board[r][c] == null && !placed.contains(r * _gridSize + c)) {
          full = false;
          break;
        }
      }
      if (full) {
        for (int r = 0; r < _gridSize; r++) {
          result.add(r * _gridSize + c);
        }
      }
    }
    return result;
  }

  void _updateHover(Offset globalPos) {
    if (_dragIndex == null || _isClearing) return;
    final piece = _tray[_dragIndex!];
    if (piece == null) return;

    final gridCtx = _gridKey.currentContext;
    final stackCtx = _stackKey.currentContext;
    if (gridCtx == null || stackCtx == null) return;
    final gridBox = gridCtx.findRenderObject() as RenderBox?;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    if (gridBox == null || !gridBox.hasSize || stackBox == null || !stackBox.hasSize) return;

    final innerSize = gridBox.size.width - _boardPadding * 2;
    final cellPx = (innerSize - _gridSpacing * (_gridSize - 1)) / _gridSize;
    final stride = cellPx + _gridSpacing;

    final liftedGlobal = globalPos - const Offset(0, _fingerLiftY);
    final gridLocal = gridBox.globalToLocal(liftedGlobal);
    final stackLocal = stackBox.globalToLocal(liftedGlobal);

    final pieceW = piece.width * cellPx + (piece.width - 1) * _gridSpacing;
    final pieceH = piece.height * cellPx + (piece.height - 1) * _gridSpacing;

    final col = ((gridLocal.dx - _boardPadding - pieceW / 2) / stride).round();
    final row = ((gridLocal.dy - _boardPadding - pieceH / 2) / stride).round();

    final valid = _canPlace(piece, row, col);
    final nearBoard = row >= -1 && row < _gridSize && col >= -1 && col < _gridSize;

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

  Future<void> _endDrag() async {
    if (_dragIndex == null) return;
    final idx = _dragIndex!;
    final piece = _tray[idx];

    if (piece != null && _hoverRow != null && _hoverCol != null && _hoverValid) {
      HapticFeedback.mediumImpact();
      for (final o in piece.cells) {
        _board[_hoverRow! + o.dy.toInt()][_hoverCol! + o.dx.toInt()] = piece.color;
      }
      _tray[idx] = null;
      final placeScore = piece.cells.length * 10;

      // Detect full rows & columns
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
        final bonus = clearedLines * 100 * _combo;
        _score += placeScore + bonus;
        if (_score > _bestScore) _saveBest(_score);

        // Build set of cells to animate before removing
        final targets = <int>{};
        for (final r in fullRows) {
          for (int c = 0; c < _gridSize; c++) {
            targets.add(r * _gridSize + c);
          }
        }
        for (final c in fullCols) {
          for (int r = 0; r < _gridSize; r++) {
            targets.add(r * _gridSize + c);
          }
        }

        // Play rich clear SFX
        if (clearedLines >= 2 || _combo >= 2) {
          _sfx.playEmp();
        } else {
          _sfx.playPowerUp();
        }

        final label = clearedLines >= 2
            ? '$clearedLines BARIS! +$bonus'
            : (_combo >= 2 ? 'COMBO x$_combo! +$bonus' : 'CLEAR! +$bonus');

        // Phase 1: HOLD & BRIGHT NEON FLASH so player clearly sees the completed line
        setState(() {
          _dragIndex = null;
          _dragStackPos = null;
          _hoverRow = null;
          _hoverCol = null;
          _hoverValid = false;
          _isClearing = true;
          _clearingCells = targets;
          _clearingPhase = 1;
          _clearBannerText = label;
        });

        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (!mounted) return;

        // Phase 2: SMOOTH SHRINK & POP OUT
        setState(() {
          _clearingPhase = 2;
        });

        await Future<void>.delayed(const Duration(milliseconds: 240));
        if (!mounted) return;

        // Phase 3: Remove cleared cells & continue
        for (final cellKey in targets) {
          _board[cellKey ~/ _gridSize][cellKey % _gridSize] = null;
        }
        setState(() {
          _isClearing = false;
          _clearingCells = <int>{};
          _clearingPhase = 0;
          _clearBannerText = null;
        });
      } else {
        _combo = 0;
        _score += placeScore;
        if (_score > _bestScore) _saveBest(_score);
        _sfx.playCoin();

        setState(() {
          _dragIndex = null;
          _dragStackPos = null;
          _hoverRow = null;
          _hoverCol = null;
          _hoverValid = false;
        });
      }

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
    final willClearCells = _computeWillClearPreview();

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1F),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFE024FF)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 9),
            const Text(
              'NEON BLOCK',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _muted ? 'Aktifkan Suara' : 'Matikan Suara',
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _muted ? Colors.white38 : const Color(0xFF00E5FF),
              size: 21,
            ),
          ),
          IconButton(
            tooltip: 'Ulangi',
            onPressed: _isClearing ? null : () => setState(_initGame),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        key: _stackKey,
        children: [
          // Clean subtle ambient studio backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.18),
                radius: 1.05,
                colors: [Color(0xFF101933), Color(0xFF060913)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  // Clean Modern Glass Score Row
                  Row(
                    children: [
                      Expanded(
                        child: _ScoreCard(
                          label: 'SKOR',
                          value: '$_score',
                          accent: const Color(0xFF00E5FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScoreCard(
                          label: 'TERBAIK',
                          value: '$_bestScore',
                          accent: const Color(0xFFFFB800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 8x8 3D Recessed Neon Board
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              key: _gridKey,
                              padding: const EdgeInsets.all(_boardPadding),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF0F162B), Color(0xFF090D1C)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                                    blurRadius: 28,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
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
                                  final isClearingCell = _clearingCells.contains(idx);
                                  final isWillClear = willClearCells.contains(idx);
                                  final previewColor = draggedPiece?.color ?? Colors.white;

                                  if (cellColor != null) {
                                    final double scale = isClearingCell
                                        ? (_clearingPhase == 1 ? 1.12 : 0.0)
                                        : 1.0;
                                    final double opacity =
                                        isClearingCell && _clearingPhase == 2 ? 0.0 : 1.0;

                                    return AnimatedOpacity(
                                      duration: const Duration(milliseconds: 210),
                                      opacity: opacity,
                                      child: AnimatedScale(
                                        duration: const Duration(milliseconds: 210),
                                        curve: _clearingPhase == 1
                                            ? Curves.easeOutBack
                                            : Curves.easeInBack,
                                        scale: scale,
                                        child: _Neon3DCube(
                                          color: isClearingCell
                                              ? Color.lerp(cellColor, Colors.white, 0.55)!
                                              : cellColor,
                                          highlighted: isClearingCell || isWillClear,
                                        ),
                                      ),
                                    );
                                  }

                                  if (isPreview) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 80),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: _hoverValid
                                            ? previewColor.withValues(alpha: 0.24)
                                            : const Color(0xFFFF3B6B).withValues(alpha: 0.22),
                                        border: Border.all(
                                          color: _hoverValid
                                              ? previewColor.withValues(alpha: 0.9)
                                              : const Color(0xFFFF3B6B),
                                          width: 1.6,
                                        ),
                                      ),
                                    );
                                  }

                                  // Clean recessed empty socket
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isWillClear
                                          ? const Color(0xFFFFB800).withValues(alpha: 0.14)
                                          : const Color(0xFF121A30),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isWillClear
                                            ? const Color(0xFFFFB800).withValues(alpha: 0.55)
                                            : Colors.white.withValues(alpha: 0.055),
                                        width: 1,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Floating Clear / Combo Banner during line-clear animation
                          if (_clearBannerText != null)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: _clearingPhase == 2 ? 0.0 : 1.0,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  scale: _clearingPhase == 1 ? 1.0 : 0.85,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                                          blurRadius: 18,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _clearBannerText!,
                                      style: const TextStyle(
                                        color: Color(0xFF060913),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Clean Modern Glass Tray
                  Container(
                    height: 108,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1224),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (i) {
                        final piece = _tray[i];
                        final hidden = _dragIndex == i || piece == null;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (piece == null || _isClearing)
                                ? null
                                : (d) {
                                    HapticFeedback.selectionClick();
                                    _sfx.playLaser();
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

          // 1:1 Pixel-Aligned Floating 3D Piece
          if (draggedPiece != null && _dragStackPos != null)
            Positioned(
              left: _dragStackPos!.dx - draggedW / 2,
              top: _dragStackPos!.dy - draggedH / 2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _hoverValid ? 0.96 : 0.82,
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
                    color: const Color(0xFF0E152B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          color: Color(0xFFFF3B6B),
                          fontSize: 23,
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
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: const Color(0xFF060913),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// Glossy 3D Neon Glass Cube with top-left specular sheen, inner crystal depth & neon rim glow.
class _Neon3DCube extends StatelessWidget {
  const _Neon3DCube({
    required this.color,
    this.highlighted = false,
  });

  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final lightTop = Color.lerp(color, Colors.white, 0.42)!;
    final deepBottom = Color.lerp(color, const Color(0xFF040712), 0.52)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightTop, color, deepBottom],
          stops: const [0.0, 0.48, 1.0],
        ),
        border: Border.all(
          color: highlighted ? Colors.white : Color.lerp(color, Colors.white, 0.55)!,
          width: highlighted ? 1.8 : 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: highlighted ? 0.85 : 0.42),
            blurRadius: highlighted ? 14 : 7,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Inner crystal recessed glass face
            Container(
              margin: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.34),
                    color.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.7,
                ),
              ),
            ),
            // Top-left glossy glass highlight glint
            Positioned(
              top: 2.5,
              left: 3,
              right: 8,
              height: 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1224),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: TextStyle(color: accent, fontSize: 19, fontWeight: FontWeight.w900),
          ),
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
              child: _Neon3DCube(color: piece.color),
            ),
        ],
      ),
    );
  }
}
