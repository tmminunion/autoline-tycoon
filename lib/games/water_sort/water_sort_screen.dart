import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaterSortScreen extends StatefulWidget {
  const WaterSortScreen({super.key});

  @override
  State<WaterSortScreen> createState() => _WaterSortScreenState();
}

class _WaterSortScreenState extends State<WaterSortScreen> {
  static const String _bestKey = 'nufat_watersort_best_v1';
  static const int _cap = 4;

  static const List<Color> _palette = [
    Color(0xFF00F5FF),
    Color(0xFFFF2D78),
    Color(0xFFFFD43B),
    Color(0xFF22C55E),
    Color(0xFFA855F7),
    Color(0xFFFF6B35),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  final Random _rng = Random();
  List<List<int>> _tubes = [];
  final List<List<List<int>>> _history = [];
  int? _selected;
  int _level = 1;
  int _bestLevel = 1;
  int _moves = 0;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _buildLevel(1);
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _bestLevel = prefs.getInt(_bestKey) ?? 1);
    } catch (_) {}
  }

  Future<void> _saveBest(int v) async {
    if (v <= _bestLevel) return;
    _bestLevel = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, v);
    } catch (_) {}
  }

  void _buildLevel(int lvl) {
    final numColors = min(4 + (lvl - 1) ~/ 2, _palette.length);
    final pool = <int>[];
    for (int c = 0; c < numColors; c++) {
      for (int k = 0; k < _cap; k++) {
        pool.add(c);
      }
    }
    pool.shuffle(_rng);

    final tubes = <List<int>>[];
    for (int i = 0; i < numColors; i++) {
      tubes.add(pool.sublist(i * _cap, (i + 1) * _cap));
    }
    // 2 empty helper tubes
    tubes.add(<int>[]);
    tubes.add(<int>[]);

    setState(() {
      _level = lvl;
      _tubes = tubes;
      _history.clear();
      _selected = null;
      _moves = 0;
      _won = false;
    });
  }

  bool _canPour(int from, int to) {
    if (from == to) return false;
    if (_tubes[from].isEmpty || _tubes[to].length >= _cap) return false;
    if (_tubes[to].isEmpty) return true;
    return _tubes[from].last == _tubes[to].last;
  }

  void _onTapTube(int idx) {
    if (_won) return;
    if (_selected == null) {
      if (_tubes[idx].isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _selected = idx);
      return;
    }

    final from = _selected!;
    if (from == idx) {
      setState(() => _selected = null);
      return;
    }

    if (_canPour(from, idx)) {
      _history.add(_tubes.map((t) => List<int>.from(t)).toList());
      final color = _tubes[from].last;
      while (_tubes[from].isNotEmpty && _tubes[from].last == color && _tubes[idx].length < _cap) {
        _tubes[idx].add(_tubes[from].removeLast());
      }
      _moves++;
      HapticFeedback.mediumImpact();
      final solved = _checkWin();
      if (solved) {
        _saveBest(_level + 1);
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _selected = null;
        _won = solved;
      });
    } else {
      HapticFeedback.selectionClick();
      setState(() => _selected = _tubes[idx].isNotEmpty ? idx : null);
    }
  }

  bool _checkWin() {
    for (final t in _tubes) {
      if (t.isEmpty) continue;
      if (t.length != _cap) return false;
      if (!t.every((c) => c == t.first)) return false;
    }
    return true;
  }

  void _undo() {
    if (_history.isEmpty || _won) return;
    setState(() {
      _tubes = _history.removeLast();
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070918),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E132B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('WATER SORT NEON', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        actions: [
          IconButton(tooltip: 'Undo', onPressed: _undo, icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: 'Ulangi', onPressed: () => _buildLevel(_level), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LEVEL $_level', style: const TextStyle(color: Color(0xFF00F5FF), fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('Langkah: $_moves  •  Terbaik: Lv $_bestLevel', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 22,
                    children: List.generate(_tubes.length, (i) {
                      final tube = _tubes[i];
                      final isSel = _selected == i;
                      return GestureDetector(
                        onTap: () => _onTapTube(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          transform: Matrix4.translationValues(0, isSel ? -16 : 0, 0),
                          width: 54,
                          height: 152,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(24)),
                            border: Border.all(
                              color: isSel ? const Color(0xFFFFD43B) : Colors.white.withValues(alpha: 0.35),
                              width: isSel ? 2.4 : 1.5,
                            ),
                            boxShadow: isSel
                                ? [BoxShadow(color: const Color(0xFFFFD43B).withValues(alpha: 0.45), blurRadius: 14)]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (int k = tube.length - 1; k >= 0; k--)
                                Container(
                                  height: 32,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: _palette[tube[k]],
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(k == tube.length - 1 ? 6 : 2),
                                      bottom: Radius.circular(k == 0 ? 16 : 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              if (_won)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101833),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF00F5FF)),
                  ),
                  child: Column(
                    children: [
                      const Text('LEVEL SELESAI!', style: TextStyle(color: Color(0xFFFFD43B), fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: Colors.black),
                        onPressed: () => _buildLevel(_level + 1),
                        child: Text('LANJUT LEVEL ${_level + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
