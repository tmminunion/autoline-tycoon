import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashPhase { title, playing, paused, gameOver }

enum DashObstacleType { oil, crate, laser }

enum DashPickupType { coin, shield, magnet, turbo }

class DashObstacle {
  DashObstacle({
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final DashObstacleType type;
  double x;
  final double y;
  final double w;
  final double h;
}

class DashPickup {
  DashPickup({
    required this.type,
    required this.x,
    required this.y,
    required this.r,
  });

  final DashPickupType type;
  double x;
  double y;
  final double r;
}

class DashParticle {
  DashParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.color,
    required this.life,
    required this.maxLife,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double r;
  final Color color;
  double life;
  final double maxLife;
}

class DashFloatText {
  DashFloatText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.life,
    required this.maxLife,
  });

  final double x;
  double y;
  final String text;
  final Color color;
  double life;
  final double maxLife;
}

class DashEngine extends ChangeNotifier {
  static const String _bestKey = 'nufat_dash_best_v1';
  static const String _coinsKey = 'nufat_dash_total_coins_v1';

  final Random _rng = Random();

  Size viewport = const Size(400, 800);
  double groundY = 600;

  DashPhase phase = DashPhase.title;
  double speed = 340;
  double distance = 0;
  double score = 0;
  int runCoins = 0;
  int totalCoins = 0;
  int bestScore = 0;
  bool isNewBest = false;

  double floorOffset = 0;
  double bgOffsetFar = 0;
  double bgOffsetMid = 0;
  double shakeTimer = 0;

  // Player state
  double playerX = 76;
  double playerY = 536;
  double playerVy = 0;
  final double playerW = 48;
  double playerH = 60;
  int jumpsUsed = 0;
  final int maxJumps = 2;
  bool sliding = false;
  double slideTimer = 0;
  double runPhase = 0;

  // Power-ups
  bool hasShield = false;
  double magnetTimer = 0;
  double turboTimer = 0;
  double invulnTimer = 0;

  final List<DashObstacle> obstacles = [];
  final List<DashPickup> pickups = [];
  final List<DashParticle> particles = [];
  final List<DashFloatText> floatTexts = [];

  double _obsSpawnTimer = 1.0;
  double _coinSpawnTimer = 0.6;
  double _powerSpawnTimer = 7.5;

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bestScore = prefs.getInt(_bestKey) ?? 0;
      totalCoins = prefs.getInt(_coinsKey) ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, bestScore);
      await prefs.setInt(_coinsKey, totalCoins);
    } catch (_) {}
  }

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final changed = (size.width - viewport.width).abs() > 1 ||
        (size.height - viewport.height).abs() > 1;
    viewport = size;
    groundY = size.height * 0.76;
    playerX = max(54, min(110, size.width * 0.18));
    if (phase == DashPhase.title || playerY > groundY - playerH) {
      playerY = groundY - playerH;
    }
    if (changed) notifyListeners();
  }

  void startGame() {
    speed = 340;
    distance = 0;
    score = 0;
    runCoins = 0;
    isNewBest = false;
    shakeTimer = 0;
    obstacles.clear();
    pickups.clear();
    particles.clear();
    floatTexts.clear();

    playerH = 60;
    playerY = groundY - playerH;
    playerVy = 0;
    jumpsUsed = 0;
    sliding = false;
    slideTimer = 0;
    hasShield = false;
    magnetTimer = 0;
    turboTimer = 0;
    invulnTimer = 0;

    _obsSpawnTimer = 1.0;
    _coinSpawnTimer = 0.55;
    _powerSpawnTimer = 7.0;

    phase = DashPhase.playing;
    notifyListeners();
  }

  void togglePause() {
    if (phase == DashPhase.playing) {
      phase = DashPhase.paused;
      notifyListeners();
    } else if (phase == DashPhase.paused) {
      phase = DashPhase.playing;
      notifyListeners();
    }
  }

  void jump() {
    if (phase != DashPhase.playing) return;
    if (jumpsUsed < maxJumps) {
      final isDouble = jumpsUsed == 1;
      sliding = false;
      slideTimer = 0;
      playerVy = isDouble ? -590 : -670;
      jumpsUsed++;
      _spawnParticles(
        playerX + playerW * 0.5,
        playerY + playerH,
        isDouble ? const Color(0xFF22D3EE) : const Color(0xFFFACC15),
        10,
      );
      notifyListeners();
    }
  }

  void slide() {
    if (phase != DashPhase.playing) return;
    if (!sliding) {
      sliding = true;
      slideTimer = 0.58;
      if (playerY < groundY - playerH) {
        playerVy = max(playerVy, 540);
      }
    } else {
      slideTimer = max(slideTimer, 0.25);
    }
    notifyListeners();
  }

  void update(double rawDt) {
    final dt = rawDt.clamp(0.0, 0.05);
    if (phase != DashPhase.playing) return;

    final turboMult = turboTimer > 0 ? 1.55 : 1.0;
    final curSpeed = speed * turboMult;

    speed = min(700, 340 + distance * 0.26);
    distance += (curSpeed * dt) / 32.0;
    score += (curSpeed * dt) * (turboTimer > 0 ? 0.05 : 0.025);

    floorOffset = (floorOffset + curSpeed * dt) % 48;
    bgOffsetFar = (bgOffsetFar + curSpeed * 0.18 * dt) % max(1, viewport.width);
    bgOffsetMid = (bgOffsetMid + curSpeed * 0.42 * dt) % 160;

    if (shakeTimer > 0) shakeTimer = max(0, shakeTimer - dt);
    if (magnetTimer > 0) magnetTimer = max(0, magnetTimer - dt);
    if (turboTimer > 0) turboTimer = max(0, turboTimer - dt);
    if (invulnTimer > 0) invulnTimer = max(0, invulnTimer - dt);

    if (sliding) {
      slideTimer -= dt;
      if (slideTimer <= 0) sliding = false;
    }

    final targetH = sliding ? 32.0 : 60.0;
    if ((playerH - targetH).abs() > 0.1) {
      final diff = playerH - targetH;
      playerH = targetH;
      playerY += diff;
    }

    playerVy += 1800 * dt;
    playerY += playerVy * dt;
    if (playerY >= groundY - playerH) {
      playerY = groundY - playerH;
      playerVy = 0;
      jumpsUsed = 0;
    }
    runPhase += dt * (curSpeed / 30.0);

    if (turboTimer > 0 && _rng.nextDouble() < 0.55) {
      particles.add(
        DashParticle(
          x: playerX + 6,
          y: playerY + playerH * 0.5 + (_rng.nextDouble() - 0.5) * 24,
          vx: -180,
          vy: (_rng.nextDouble() - 0.5) * 36,
          r: 3.5,
          color: const Color(0xFF22D3EE),
          life: 0.24,
          maxLife: 0.24,
        ),
      );
    }

    // Spawners
    _obsSpawnTimer -= dt;
    if (_obsSpawnTimer <= 0) {
      _spawnObstacle();
      final baseGap = max(0.74, 1.48 - distance * 0.0007);
      _obsSpawnTimer = baseGap + _rng.nextDouble() * 0.55;
    }

    _coinSpawnTimer -= dt;
    if (_coinSpawnTimer <= 0) {
      _spawnCoinArc();
      _coinSpawnTimer = 1.7 + _rng.nextDouble() * 1.3;
    }

    _powerSpawnTimer -= dt;
    if (_powerSpawnTimer <= 0) {
      _spawnPowerUp();
      _powerSpawnTimer = 10.0 + _rng.nextDouble() * 6.0;
    }

    // Forgiving player hitbox
    final px = playerX + 7;
    final py = playerY + 5;
    final pw = playerW - 14;
    final ph = playerH - 8;

    // Update obstacles
    for (int i = obstacles.length - 1; i >= 0; i--) {
      final o = obstacles[i];
      o.x -= curSpeed * dt;
      if (o.x + o.w < -40) {
        obstacles.removeAt(i);
        continue;
      }
      final hit = px < o.x + o.w - 4 &&
          px + pw > o.x + 4 &&
          py < o.y + o.h - 3 &&
          py + ph > o.y + 3;
      if (hit) {
        if (turboTimer > 0) {
          score += 25;
          _spawnParticles(o.x + o.w * 0.5, o.y + o.h * 0.5, const Color(0xFF22D3EE), 14);
          _addFloatText(o.x, o.y - 10, '+25 SMASH!', const Color(0xFF22D3EE));
          obstacles.removeAt(i);
        } else if (invulnTimer > 0) {
          continue;
        } else if (hasShield) {
          hasShield = false;
          invulnTimer = 1.2;
          shakeTimer = 0.24;
          _spawnParticles(playerX + playerW * 0.5, playerY + playerH * 0.5, const Color(0xFFFACC15), 20);
          _addFloatText(playerX, playerY - 12, 'SHIELD PECAH!', const Color(0xFFFACC15));
          obstacles.removeAt(i);
        } else {
          _spawnParticles(playerX + playerW * 0.5, playerY + playerH * 0.5, const Color(0xFFFB7185), 24);
          _triggerGameOver();
          return;
        }
      }
    }

    // Update pickups
    final pCx = playerX + playerW * 0.5;
    final pCy = playerY + playerH * 0.5;
    for (int i = pickups.length - 1; i >= 0; i--) {
      final p = pickups[i];
      p.x -= curSpeed * dt;
      if (p.type == DashPickupType.coin && magnetTimer > 0) {
        final dx = pCx - p.x;
        final dy = pCy - p.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d < 220 && d > 1) {
          p.x += (dx / d) * 460 * dt;
          p.y += (dy / d) * 460 * dt;
        }
      }
      if (p.x + p.r < -30) {
        pickups.removeAt(i);
        continue;
      }
      final distToPlayer = sqrt(pow(pCx - p.x, 2) + pow(pCy - p.y, 2));
      if (distToPlayer < p.r + 26) {
        switch (p.type) {
          case DashPickupType.coin:
            runCoins++;
            totalCoins++;
            final pts = turboTimer > 0 ? 20 : 10;
            score += pts;
            _spawnParticles(p.x, p.y, const Color(0xFFFACC15), 5);
            _addFloatText(p.x, p.y - 10, '+$pts', const Color(0xFFFACC15));
            break;
          case DashPickupType.shield:
            hasShield = true;
            _spawnParticles(p.x, p.y, const Color(0xFFFACC15), 14);
            _addFloatText(p.x, p.y - 12, 'SHIELD!', const Color(0xFFFACC15));
            break;
          case DashPickupType.magnet:
            magnetTimer = 7.0;
            _spawnParticles(p.x, p.y, const Color(0xFFC084FC), 14);
            _addFloatText(p.x, p.y - 12, 'MAGNET!', const Color(0xFFE9D5FF));
            break;
          case DashPickupType.turbo:
            turboTimer = 5.0;
            _spawnParticles(p.x, p.y, const Color(0xFF22D3EE), 16);
            _addFloatText(p.x, p.y - 12, 'TURBO 2X!', const Color(0xFF22D3EE));
            break;
        }
        pickups.removeAt(i);
      }
    }

    // Update particles & float texts
    for (int i = particles.length - 1; i >= 0; i--) {
      final pt = particles[i];
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.vy += 420 * dt;
      pt.life -= dt;
      if (pt.life <= 0) particles.removeAt(i);
    }
    for (int i = floatTexts.length - 1; i >= 0; i--) {
      final ft = floatTexts[i];
      ft.y -= 48 * dt;
      ft.life -= dt;
      if (ft.life <= 0) floatTexts.removeAt(i);
    }

    notifyListeners();
  }

  void _triggerGameOver() {
    phase = DashPhase.gameOver;
    shakeTimer = 0.3;
    final finalScore = score.floor();
    if (finalScore > bestScore) {
      bestScore = finalScore;
      isNewBest = true;
    }
    _savePrefs();
    notifyListeners();
  }

  void _spawnObstacle() {
    final roll = _rng.nextDouble();
    final x = viewport.width + 40;
    if (roll < 0.36) {
      obstacles.add(DashObstacle(type: DashObstacleType.oil, x: x, y: groundY - 16, w: 62, h: 16));
    } else if (roll < 0.72) {
      final h = 42.0 + _rng.nextInt(14);
      obstacles.add(DashObstacle(type: DashObstacleType.crate, x: x, y: groundY - h, w: 44, h: h));
    } else {
      obstacles.add(DashObstacle(type: DashObstacleType.laser, x: x, y: groundY - 78, w: 64, h: 34));
    }
  }

  void _spawnCoinArc() {
    final pattern = _rng.nextDouble();
    final count = 4 + _rng.nextInt(3);
    final startX = viewport.width + 60;
    for (int i = 0; i < count; i++) {
      double cy = groundY - 34;
      if (pattern < 0.5) {
        final t = i / max(1, count - 1);
        cy = groundY - 40 - sin(t * pi) * 90;
      } else if (pattern < 0.8) {
        cy = groundY - 24;
      } else {
        cy = groundY - 120;
      }
      pickups.add(DashPickup(type: DashPickupType.coin, x: startX + i * 36, y: cy, r: 11));
    }
  }

  void _spawnPowerUp() {
    const types = [DashPickupType.shield, DashPickupType.magnet, DashPickupType.turbo];
    final type = types[_rng.nextInt(types.length)];
    pickups.add(
      DashPickup(
        type: type,
        x: viewport.width + 60,
        y: groundY - 88 - _rng.nextDouble() * 44,
        r: 16,
      ),
    );
  }

  void _spawnParticles(double x, double y, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 70 + _rng.nextDouble() * 200;
      final life = 0.3 + _rng.nextDouble() * 0.3;
      particles.add(
        DashParticle(
          x: x,
          y: y,
          vx: cos(a) * sp,
          vy: sin(a) * sp - 40,
          r: 2.5 + _rng.nextDouble() * 3,
          color: color,
          life: life,
          maxLife: life,
        ),
      );
    }
  }

  void _addFloatText(double x, double y, String text, Color color) {
    floatTexts.add(DashFloatText(x: x, y: y, text: text, color: color, life: 0.8, maxLife: 0.8));
  }
}
