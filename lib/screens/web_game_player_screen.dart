import 'dart:convert';

import 'package:flutter/material.dart';
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final accent = widget.game.accentColor;
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF071024),
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.35))),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          'Cloud WebView · ${widget.game.genre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _hasError = false);
                      _controller.reload();
                    },
                    icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
                  ),
                ],
              ),
            ),
            if (_progress > 0 && _progress < 100)
              LinearProgressIndicator(
                value: _progress / 100.0,
                minHeight: 2.5,
                backgroundColor: const Color(0xFF071024),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            Expanded(
              child: _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 46, color: accent),
                            const SizedBox(height: 12),
                            const Text(
                              'Gagal memuat Cloud Game',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pastikan koneksi internet aktif untuk memainkan game WebView, atau mainkan game Ori Native secara offline.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: const Color(0xFF050714)),
                              onPressed: () {
                                setState(() => _hasError = false);
                                _controller.loadRequest(Uri.parse(widget.game.url));
                              },
                              icon: const Icon(Icons.refresh_rounded),
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
    );
  }
}
