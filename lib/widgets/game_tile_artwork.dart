import 'package:flutter/material.dart';

class GameTileArtwork extends StatelessWidget {
  const GameTileArtwork({
    super.key,
    required this.id,
    required this.category,
    required this.colors,
    required this.icon,
    this.emoji,
    this.compact = false,
  });

  final String id;
  final String category;
  final List<Color> colors;
  final IconData icon;
  final String? emoji;
  final bool compact;

  String _resolveAssetPath() {
    final keyId = id.toLowerCase();
    final cat = category.toLowerCase();

    if (keyId.contains('striker') || keyId.contains('space') || keyId.contains('shooter')) {
      return 'assets/games/neon_striker.webp';
    }
    if (keyId.contains('dash') || keyId.contains('runner')) {
      return 'assets/games/neon_dash.webp';
    }
    if (keyId.contains('catur') || keyId.contains('chess')) {
      return 'assets/games/catur_ori.webp';
    }
    if (keyId.contains('match') || keyId.contains('gem') || keyId.contains('jewel')) {
      return 'assets/games/neon_match.webp';
    }
    if (keyId.contains('sos') || keyId.contains('tic')) {
      return 'assets/games/sos_ai.webp';
    }
    if (keyId.contains('stack') || keyId.contains('tower')) {
      return 'assets/games/neon_stack.webp';
    }
    if (keyId.contains('brick') || keyId.contains('breakout')) {
      return 'assets/games/brick_breaker.webp';
    }
    if (keyId.contains('snake') || keyId.contains('ular')) {
      return 'assets/games/snake_neon.webp';
    }
    if (keyId.contains('2048')) {
      return 'assets/games/puzzle_2048.webp';
    }

    if (cat.contains('kuis') || cat.contains('quiz') || cat.contains('trivia')) {
      return 'assets/games/quiz_hub.webp';
    }
    if (cat.contains('kata') || cat.contains('word') || cat.contains('memory')) {
      return 'assets/games/word_hub.webp';
    }
    if (cat.contains('puzzle')) {
      return 'assets/games/puzzle_2048.webp';
    }
    return 'assets/games/arcade_hub.webp';
  }

  @override
  Widget build(BuildContext context) {
    final fallbackColor = colors.isNotEmpty ? colors.first : const Color(0xFF1E293B);
    final assetPath = _resolveAssetPath();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: fallbackColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          // Subtle top-left glossy sheen
          Positioned(
            top: -24,
            left: -20,
            right: -10,
            height: compact ? 54 : 68,
            child: Transform.rotate(
              angle: -0.20,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
