import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/remote_games_service.dart';

class WebGamePlayerScreen extends StatefulWidget {
  const WebGamePlayerScreen({super.key, required this.game});

  final RemoteWebGame game;

  @override
  State<WebGamePlayerScreen> createState() => _WebGamePlayerScreenState();
}

class _WebGamePlayerScreenState extends State<WebGamePlayerScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  int _bestScore = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050714))
      ..addJavaScriptChannel(
        'NufatGamesBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = jsonDecode(msg.message);
            if (data is Map && data['event'] == 'score') {
              final score = data['score'] is num
                  ? (data['score'] as num).toInt()
                  : int.tryParse('${data['score'] ?? 0}') ?? 0;
              final gid = '${data['gameId'] ?? widget.game.id}';
              RemoteGamesService.instance.recordWebScore(gid, score);
              if (mounted && score > _bestScore) {
                setState(() => _bestScore = score);
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _hasError = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _hasError = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.game.url));
  }

  Future<void> _loadBestScore() async {
    try {
      final map = await RemoteGamesService.instance.loadWebBestScores([widget.game]);
      final best = map[widget.game.id] ?? 0;
      if (mounted && best > _bestScore) {
        setState(() => _bestScore = best);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.game.accentColor;
    final isLoading = _progress > 0 && _progress < 100;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF050714),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF050714),
        body: SafeArea(
          child: Column(
            children: [
              // Sleek Glass-Accent Game Header
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0C142B), Color(0xFF070C1D)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          // Glass Back Button
                          _HeaderActionBtn(
                            icon: Icons.arrow_back_ios_new_rounded,
                            iconSize: 16,
                            iconColor: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.06),
                            borderColor: Colors.white.withValues(alpha: 0.10),
                            tooltip: 'Kembali',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          // Game Emoji Badge
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.30),
                                  accent.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(color: accent.withValues(alpha: 0.40)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.game.emoji,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title + Genre Pill
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.game.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.25,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(alpha: 0.75),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        widget.game.genre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: accent.withValues(alpha: 0.92),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_bestScore > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFACC15).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 12,
                                    color: Color(0xFFFACC15),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_bestScore',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFDE047),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          // Accent Refresh Button
                          _HeaderActionBtn(
                            icon: Icons.refresh_rounded,
                            iconSize: 18,
                            iconColor: accent,
                            bgColor: accent.withValues(alpha: 0.12),
                            borderColor: accent.withValues(alpha: 0.32),
                            tooltip: 'Muat Ulang',
                            onTap: () {
                              setState(() => _hasError = false);
                              _controller.reload();
                            },
                          ),
                        ],
                      ),
                    ),
                    // Subtle Neon Hairline / Loading Bar
                    if (isLoading)
                      LinearProgressIndicator(
                        value: _progress / 100.0,
                        minHeight: 2,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      )
                    else
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              accent.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                                ),
                                child: Icon(Icons.wifi_off_rounded, size: 30, color: accent),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Gagal memuat Cloud Game',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pastikan koneksi internet aktif untuk memainkan game ini, atau mainkan game Ori Native secara offline.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: const Color(0xFF050714),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                onPressed: () {
                                  setState(() => _hasError = false);
                                  _controller.loadRequest(Uri.parse(widget.game.url));
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionBtn extends StatelessWidget {
  const _HeaderActionBtn({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}
