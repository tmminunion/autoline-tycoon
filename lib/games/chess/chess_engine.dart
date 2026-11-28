import 'dart:math';

enum ChessMode { easy, pro, pvp }

class ChessMove {
  const ChessMove({
    required this.fr,
    required this.fc,
    required this.tr,
    required this.tc,
    this.extra,
  });

  final int fr;
  final int fc;
  final int tr;
  final int tc;
  final String? extra; // 'promo' | 'ep' | 'castleK' | 'castleQ'
}

class ChessSnapshot {
  ChessSnapshot({
    required this.fr,
    required this.fc,
    required this.tr,
    required this.tc,
    required this.board,
    required this.castleRights,
    required this.enPassant,
    required this.capturedW,
    required this.capturedB,
    required this.turn,
  });

  final int fr;
  final int fc;
  final int tr;
  final int tc;
  final List<List<String?>> board;
  final Map<String, bool> castleRights;
  final List<int>? enPassant;
  final List<String> capturedW;
  final List<String> capturedB;
  final String turn;
}

class ChessEngine {
  static const Map<String, String> pieceSymbols = {
    'wK': '♔', 'wQ': '♕', 'wR': '♖', 'wB': '♗', 'wN': '♘', 'wP': '♙',
    'bK': '♚', 'bQ': '♛', 'bR': '♜', 'bB': '♝', 'bN': '♞', 'bP': '♟',
  };

  static const Map<String, int> pieceValues = {
    'P': 100, 'N': 320, 'B': 330, 'R': 500, 'Q': 900, 'K': 20000,
  };

  static const Map<String, List<List<int>>> pst = {
    'P': [
      [0, 0, 0, 0, 0, 0, 0, 0],
      [50, 50, 50, 50, 50, 50, 50, 50],
      [10, 10, 20, 30, 30, 20, 10, 10],
      [5, 5, 10, 25, 25, 10, 5, 5],
      [0, 0, 0, 20, 20, 0, 0, 0],
      [5, -5, -10, 0, 0, -10, -5, 5],
      [5, 10, 10, -20, -20, 10, 10, 5],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    'N': [
      [-50, -40, -30, -30, -30, -30, -40, -50],
      [-40, -20, 0, 0, 0, 0, -20, -40],
      [-30, 0, 10, 15, 15, 10, 0, -30],
      [-30, 5, 15, 20, 20, 15, 5, -30],
      [-30, 0, 15, 20, 20, 15, 0, -30],
      [-30, 5, 10, 15, 15, 10, 5, -30],
      [-40, -20, 0, 5, 5, 0, -20, -40],
      [-50, -40, -30, -30, -30, -30, -40, -50],
    ],
    'B': [
      [-20, -10, -10, -10, -10, -10, -10, -20],
      [-10, 0, 0, 0, 0, 0, 0, -10],
      [-10, 0, 5, 10, 10, 5, 0, -10],
      [-10, 5, 5, 10, 10, 5, 5, -10],
      [-10, 0, 10, 10, 10, 10, 0, -10],
      [-10, 10, 10, 10, 10, 10, 10, -10],
      [-10, 5, 0, 0, 0, 0, 5, -10],
      [-20, -10, -10, -10, -10, -10, -10, -20],
    ],
    'R': [
      [0, 0, 0, 0, 0, 0, 0, 0],
      [5, 10, 10, 10, 10, 10, 10, 5],
      [-5, 0, 0, 0, 0, 0, 0, -5],
      [-5, 0, 0, 0, 0, 0, 0, -5],
      [-5, 0, 0, 0, 0, 0, 0, -5],
      [-5, 0, 0, 0, 0, 0, 0, -5],
      [-5, 0, 0, 0, 0, 0, 0, -5],
      [0, 0, 0, 5, 5, 0, 0, 0],
    ],
    'Q': [
      [-20, -10, -10, -5, -5, -10, -10, -20],
      [-10, 0, 0, 0, 0, 0, 0, -10],
      [-10, 0, 5, 5, 5, 5, 0, -10],
      [-5, 0, 5, 5, 5, 5, 0, -5],
      [0, 0, 5, 5, 5, 5, 0, -5],
      [-10, 5, 5, 5, 5, 5, 0, -10],
      [-10, 0, 5, 0, 0, 0, 0, -10],
      [-20, -10, -10, -5, -5, -10, -10, -20],
    ],
    'K': [
      [-30, -40, -40, -50, -50, -40, -40, -30],
      [-30, -40, -40, -50, -50, -40, -40, -30],
      [-30, -40, -40, -50, -50, -40, -40, -30],
      [-30, -40, -40, -50, -50, -40, -40, -30],
      [-20, -30, -30, -40, -40, -30, -30, -20],
      [-10, -20, -20, -20, -20, -20, -20, -10],
      [20, 20, 0, 0, 0, 0, 20, 20],
      [20, 30, 10, 0, 0, 10, 30, 20],
    ],
  };

  List<List<String?>> board = [];
  String turn = 'w';
  Map<String, bool> castleRights = {'wK': true, 'wQ': true, 'bK': true, 'bQ': true};
  List<int>? enPassant;
  List<String> capturedW = [];
  List<String> capturedB = [];
  List<ChessSnapshot> history = [];

  ChessEngine() {
    reset();
  }

  ChessEngine clone() {
    final c = ChessEngine();
    c.board = _cloneBoard(board);
    c.turn = turn;
    c.castleRights = Map<String, bool>.from(castleRights);
    c.enPassant = enPassant == null ? null : List<int>.from(enPassant!);
    c.capturedW = List<String>.from(capturedW);
    c.capturedB = List<String>.from(capturedB);
    return c;
  }

  static List<List<String?>> _cloneBoard(List<List<String?>> b) {
    return List<List<String?>>.generate(8, (r) => List<String?>.from(b[r]));
  }

  void reset() {
    const order = ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'];
    board = List<List<String?>>.generate(8, (_) => List<String?>.filled(8, null));
    for (int c = 0; c < 8; c++) {
      board[0][c] = 'b${order[c]}';
      board[1][c] = 'bP';
      board[6][c] = 'wP';
      board[7][c] = 'w${order[c]}';
    }
    turn = 'w';
    castleRights = {'wK': true, 'wQ': true, 'bK': true, 'bQ': true};
    enPassant = null;
    capturedW = [];
    capturedB = [];
    history = [];
  }

  List<ChessMove> getLegalMoves(int r, int c) {
    final piece = board[r][c];
    if (piece == null) return const [];
    final color = piece[0];
    final savedCR = Map<String, bool>.from(castleRights);
    final savedEP = enPassant == null ? null : List<int>.from(enPassant!);
    final result = <ChessMove>[];

    for (final m in _getPseudoMoves(r, c, board, false)) {
      final snap = _cloneBoard(board);
      _applyRaw(board, m);
      final ok = !isInCheck(color, board);
      board = snap;
      castleRights = Map<String, bool>.from(savedCR);
      enPassant = savedEP == null ? null : List<int>.from(savedEP);
      if (ok) result.add(m);
    }
    return result;
  }

  List<ChessMove> getAllLegal(String color) {
    final all = <ChessMove>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p[0] == color) {
          all.addAll(getLegalMoves(r, c));
        }
      }
    }
    return all;
  }

  List<ChessMove> _getPseudoMoves(int r, int c, List<List<String?>> b, bool forAttack) {
    final piece = b[r][c];
    if (piece == null) return const [];
    final color = piece[0];
    final type = piece[1];
    final moves = <ChessMove>[];

    bool add(int tr, int tc, [String? extra]) {
      if (tr < 0 || tr > 7 || tc < 0 || tc > 7) return false;
      final t = b[tr][tc];
      if (t != null && t[0] == color) return false;
      moves.add(ChessMove(fr: r, fc: c, tr: tr, tc: tc, extra: extra));
      return t == null;
    }

    void slide(List<List<int>> dirs) {
      for (final d in dirs) {
        int nr = r + d[0];
        int nc = c + d[1];
        while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
          final t = b[nr][nc];
          if (t != null && t[0] == color) break;
          moves.add(ChessMove(fr: r, fc: c, tr: nr, tc: nc));
          if (t != null) break;
          nr += d[0];
          nc += d[1];
        }
      }
    }

    if (type == 'P') {
      final dir = color == 'w' ? -1 : 1;
      final startRow = color == 'w' ? 6 : 1;
      final nr = r + dir;
      if (!forAttack && nr >= 0 && nr < 8 && b[nr][c] == null) {
        moves.add(ChessMove(fr: r, fc: c, tr: nr, tc: c, extra: (nr == 0 || nr == 7) ? 'promo' : null));
        if (r == startRow && b[r + dir * 2][c] == null) {
          moves.add(ChessMove(fr: r, fc: c, tr: r + dir * 2, tc: c));
        }
      }
      for (final dc in const [-1, 1]) {
        final tc = c + dc;
        if (tc < 0 || tc > 7 || nr < 0 || nr > 7) continue;
        if (forAttack) {
          moves.add(ChessMove(fr: r, fc: c, tr: nr, tc: tc));
          continue;
        }
        final target = b[nr][tc];
        if (target != null && target[0] != color) {
          moves.add(ChessMove(fr: r, fc: c, tr: nr, tc: tc, extra: (nr == 0 || nr == 7) ? 'promo' : null));
        }
        if (enPassant != null && enPassant![0] == nr && enPassant![1] == tc) {
          moves.add(ChessMove(fr: r, fc: c, tr: nr, tc: tc, extra: 'ep'));
        }
      }
    } else if (type == 'N') {
      for (final d in const [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]) {
        add(r + d[0], c + d[1]);
      }
    } else if (type == 'B') {
      slide(const [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
    } else if (type == 'R') {
      slide(const [[-1, 0], [1, 0], [0, -1], [0, 1]]);
    } else if (type == 'Q') {
      slide(const [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]);
    } else if (type == 'K') {
      for (final d in const [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]) {
        add(r + d[0], c + d[1]);
      }
      if (!forAttack) {
        final row = color == 'w' ? 7 : 0;
        if (r == row && c == 4) {
          if ((castleRights['${color}K'] ?? false) &&
              b[row][5] == null &&
              b[row][6] == null &&
              !_isAttacked(row, 4, color, b) &&
              !_isAttacked(row, 5, color, b) &&
              !_isAttacked(row, 6, color, b)) {
            moves.add(ChessMove(fr: r, fc: c, tr: row, tc: 6, extra: 'castleK'));
          }
          if ((castleRights['${color}Q'] ?? false) &&
              b[row][3] == null &&
              b[row][2] == null &&
              b[row][1] == null &&
              !_isAttacked(row, 4, color, b) &&
              !_isAttacked(row, 3, color, b) &&
              !_isAttacked(row, 2, color, b)) {
            moves.add(ChessMove(fr: r, fc: c, tr: row, tc: 2, extra: 'castleQ'));
          }
        }
      }
    }

    return moves;
  }

  bool _isAttacked(int r, int c, String byColor, List<List<String?>> b) {
    final opp = byColor == 'w' ? 'b' : 'w';
    for (int br = 0; br < 8; br++) {
      for (int bc = 0; bc < 8; bc++) {
        final p = b[br][bc];
        if (p == null || p[0] != opp) continue;
        for (final m in _getPseudoMoves(br, bc, b, true)) {
          if (m.tr == r && m.tc == c) return true;
        }
      }
    }
    return false;
  }

  bool isInCheck(String color, [List<List<String?>>? customBoard]) {
    final b = customBoard ?? board;
    int kr = -1, kc = -1;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (b[r][c] == '${color}K') {
          kr = r;
          kc = c;
        }
      }
    }
    if (kr == -1) return false;
    return _isAttacked(kr, kc, color, b);
  }

  void _applyRaw(List<List<String?>> b, ChessMove m) {
    final piece = b[m.fr][m.fc]!;
    final color = piece[0];
    if (m.extra == 'ep') {
      final dir = color == 'w' ? 1 : -1;
      b[m.tr + dir][m.tc] = null;
    } else if (m.extra == 'castleK') {
      b[m.tr][m.tc - 1] = b[m.tr][7];
      b[m.tr][7] = null;
    } else if (m.extra == 'castleQ') {
      b[m.tr][m.tc + 1] = b[m.tr][0];
      b[m.tr][0] = null;
    }

    b[m.tr][m.tc] = piece;
    b[m.fr][m.fc] = null;

    if (piece == 'wK') {
      castleRights['wK'] = false;
      castleRights['wQ'] = false;
    } else if (piece == 'bK') {
      castleRights['bK'] = false;
      castleRights['bQ'] = false;
    }
    if (m.fr == 7 && m.fc == 0) castleRights['wQ'] = false;
    if (m.fr == 7 && m.fc == 7) castleRights['wK'] = false;
    if (m.fr == 0 && m.fc == 0) castleRights['bQ'] = false;
    if (m.fr == 0 && m.fc == 7) castleRights['bK'] = false;

    enPassant = null;
    if (piece[1] == 'P' && (m.tr - m.fr).abs() == 2) {
      enPassant = [(m.fr + m.tr) ~/ 2, m.fc];
    }
  }

  void commitMove(ChessMove m, {String promotionPiece = 'Q'}) {
    final captured = board[m.tr][m.tc];
    history.add(ChessSnapshot(
      fr: m.fr,
      fc: m.fc,
      tr: m.tr,
      tc: m.tc,
      board: _cloneBoard(board),
      castleRights: Map<String, bool>.from(castleRights),
      enPassant: enPassant == null ? null : List<int>.from(enPassant!),
      capturedW: List<String>.from(capturedW),
      capturedB: List<String>.from(capturedB),
      turn: turn,
    ));

    if (captured != null) {
      if (captured[0] == 'w') {
        capturedW.add(captured[1]);
      } else {
        capturedB.add(captured[1]);
      }
    }
    if (m.extra == 'ep') {
      final dir = turn == 'w' ? 1 : -1;
      final ep = board[m.tr + dir][m.tc];
      if (ep != null) {
        if (ep[0] == 'w') {
          capturedW.add(ep[1]);
        } else {
          capturedB.add(ep[1]);
        }
      }
    }

    _applyRaw(board, m);
    if (m.extra == 'promo') {
      board[m.tr][m.tc] = '$turn$promotionPiece';
    }
    turn = turn == 'w' ? 'b' : 'w';
  }

  bool undo({int steps = 1}) {
    if (history.isEmpty) return false;
    for (int i = 0; i < steps && history.isNotEmpty; i++) {
      final s = history.removeLast();
      board = _cloneBoard(s.board);
      castleRights = Map<String, bool>.from(s.castleRights);
      enPassant = s.enPassant == null ? null : List<int>.from(s.enPassant!);
      capturedW = List<String>.from(s.capturedW);
      capturedB = List<String>.from(s.capturedB);
      turn = s.turn;
    }
    return true;
  }

  int _evaluate() {
    int score = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null) continue;
        final col = p[0];
        final type = p[1];
        final row = col == 'b' ? r : 7 - r;
        final val = (pieceValues[type] ?? 0) + (pst[type]?[row][c] ?? 0);
        score += col == 'b' ? val : -val;
      }
    }
    return score;
  }

  int _minimax(int depth, int alpha, int beta, bool maximizing) {
    if (depth == 0) return _evaluate();
    final color = maximizing ? 'b' : 'w';
    final moves = getAllLegal(color);
    if (moves.isEmpty) {
      if (isInCheck(color)) return maximizing ? -50000 - depth : 50000 + depth;
      return 0;
    }

    moves.sort((a, b) {
      final va = board[a.tr][a.tc] != null ? (pieceValues[board[a.tr][a.tc]![1]] ?? 0) : 0;
      final vb = board[b.tr][b.tc] != null ? (pieceValues[board[b.tr][b.tc]![1]] ?? 0) : 0;
      return vb.compareTo(va);
    });

    final savedCR = Map<String, bool>.from(castleRights);
    final savedEP = enPassant == null ? null : List<int>.from(enPassant!);

    int best = maximizing ? -999999 : 999999;
    for (final m in moves) {
      final snap = _cloneBoard(board);
      _applyRaw(board, m);
      if (m.extra == 'promo') board[m.tr][m.tc] = '${color}Q';

      final sc = _minimax(depth - 1, alpha, beta, !maximizing);

      board = snap;
      castleRights = Map<String, bool>.from(savedCR);
      enPassant = savedEP == null ? null : List<int>.from(savedEP);

      if (maximizing) {
        if (sc > best) best = sc;
        if (sc > alpha) alpha = sc;
      } else {
        if (sc < best) best = sc;
        if (sc < beta) beta = sc;
      }
      if (beta <= alpha) break;
    }
    return best;
  }

  ChessMove? computeBestAiMove(ChessMode mode) {
    final moves = getAllLegal('b');
    if (moves.isEmpty) return null;
    final rng = Random();

    if (mode == ChessMode.easy) {
      if (rng.nextDouble() < 0.45) return moves[rng.nextInt(moves.length)];
      final caps = moves.where((m) => board[m.tr][m.tc] != null).toList();
      if (caps.isNotEmpty && rng.nextDouble() < 0.72) {
        return caps[rng.nextInt(caps.length)];
      }
      return moves[rng.nextInt(moves.length)];
    }

    // Pro AI: Minimax depth 3 with alpha-beta pruning
    moves.sort((a, b) {
      final va = board[a.tr][a.tc] != null ? (pieceValues[board[a.tr][a.tc]![1]] ?? 0) : 0;
      final vb = board[b.tr][b.tc] != null ? (pieceValues[board[b.tr][b.tc]![1]] ?? 0) : 0;
      return vb.compareTo(va);
    });

    final savedCR = Map<String, bool>.from(castleRights);
    final savedEP = enPassant == null ? null : List<int>.from(enPassant!);

    ChessMove bestMove = moves.first;
    int bestScore = -999999;

    for (final m in moves) {
      final snap = _cloneBoard(board);
      _applyRaw(board, m);
      if (m.extra == 'promo') board[m.tr][m.tc] = 'bQ';

      final sc = _minimax(2, -999999, 999999, false);

      board = snap;
      castleRights = Map<String, bool>.from(savedCR);
      enPassant = savedEP == null ? null : List<int>.from(savedEP);

      if (sc > bestScore) {
        bestScore = sc;
        bestMove = m;
      }
    }
    return bestMove;
  }
}

/// Top-level isolate runner for compute() so Pro AI never blocks UI frame rendering.
ChessMove? computeChessAiIsolate(Map<String, dynamic> payload) {
  final engine = ChessEngine();
  final rawBoard = (payload['board'] as List).cast<List>();
  engine.board = rawBoard.map((row) => row.map((e) => e as String?).toList()).toList();
  engine.turn = payload['turn'] as String;
  engine.castleRights = Map<String, bool>.from(payload['castleRights'] as Map);
  engine.enPassant = payload['enPassant'] == null ? null : List<int>.from(payload['enPassant'] as List);
  final mode = ChessMode.values[payload['mode'] as int];
  return engine.computeBestAiMove(mode);
}
