import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sound_service.dart';
import 'entities.dart';

class ArcadeGameEngine extends ChangeNotifier {
  static const String _highScoreKey = 'neon_striker_high_score_v1';
  static const String _muteKey = 'neon_striker_muted_v1';
  static const String _coinsKey = 'neon_striker_coins_v1';
  static const String _selectedShipKey = 'neon_striker_selected_ship_v1';
  static const String _unlockedShipsKey = 'neon_striker_unlocked_ships_v1';
  static const String _hullUpgradeKey = 'neon_striker_upg_hull_v1';
  static const String _fireUpgradeKey = 'neon_striker_upg_fire_v1';
  static const String _magnetUpgradeKey = 'neon_striker_upg_magnet_v1';

  static const int maxUpgradeLevel = 5;

  final Random _rng = Random();
  final SoundService sound = SoundService();

  Size viewport = const Size(400, 800);
  GamePhase phase = GamePhase.title;

  // Persistent meta-progression (Coins, Ships, Permanent Upgrades)
  int coins = 0;
  int runCoins = 0;
  ShipType selectedShip = ShipType.viper;
  ShipType previewShip = ShipType.viper;
  final Set<ShipType> unlockedShips = {ShipType.viper};

  int hullUpgradeLv = 0; // +1 Max HP per level
  int fireUpgradeLv = 0; // +10% fire rate per level, +1 start WPN at lv 3+
  int magnetUpgradeLv = 0; // +42px coin magnet radius, +1 start EMP at lv 2 & 4

  // Player state
  double playerX = 200;
  double playerY = 640;
  double playerTargetX = 200;
  double playerTargetY = 640;
  double playerTilt = 0.0;
  final double playerRadius = 18.0;

  int hp = 3;
  int maxHp = 3;
  bool hasShield = false;
  int weaponLevel = 1; // 1..4
  int empCharges = 2;
  double invulnTimer = 0.0;
  double overdriveTimer = 0.0;

  // Score & progression
  int score = 0;
  int highScore = 0;
  int wave = 1;
  int killsInWave = 0;
  int killsForNextWave = 10;
  int combo = 0;
  double comboTimer = 0.0;
  bool bossActive = false;
  double waveBannerTimer = 0.0;

  // Timers & camera juice
  double elapsedTime = 0.0;
  double _fireCooldown = 0.0;
  double _spawnTimer = 0.8;
  double _thrusterTimer = 0.0;
  double shakeTimer = 0.0;
  double shakeIntensity = 0.0;
  double gridOffset = 0.0;

  // World entities
  final List<Star> stars = [];
  final List<Bullet> bullets = [];
  final List<Enemy> enemies = [];
  final List<Particle> particles = [];
  final List<PowerUp> powerUps = [];
  final List<CoinOrb> coinOrbs = [];
  final List<FloatingText> floatingTexts = [];
  final List<Shockwave> shockwaves = [];

  ArcadeGameEngine() {
    _initStars(const Size(400, 800));
  }

  bool get isMuted => sound.isMuted;
  bool get isOverdrive => overdriveTimer > 0;

  ShipSpec get activeShipSpec => kShipSpecs[selectedShip]!;
  ShipSpec get displayedShipSpec =>
      kShipSpecs[phase == GamePhase.hangar ? previewShip : selectedShip]!;

  bool isShipUnlocked(ShipType type) => unlockedShips.contains(type);

  int get hullUpgradeCost => 120 * (hullUpgradeLv + 1);
  int get fireUpgradeCost => 150 * (fireUpgradeLv + 1);
  int get magnetUpgradeCost => 100 * (magnetUpgradeLv + 1);

  double get coinMagnetRadius => 95.0 + magnetUpgradeLv * 42.0;

  Enemy? get activeBoss {
    for (final e in enemies) {
      if (e.type == EnemyType.boss) return e;
    }
    return null;
  }

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt(_highScoreKey) ?? 0;
      sound.isMuted = prefs.getBool(_muteKey) ?? false;
      coins = prefs.getInt(_coinsKey) ?? 0;
      hullUpgradeLv =
          (prefs.getInt(_hullUpgradeKey) ?? 0).clamp(0, maxUpgradeLevel);
      fireUpgradeLv =
          (prefs.getInt(_fireUpgradeKey) ?? 0).clamp(0, maxUpgradeLevel);
      magnetUpgradeLv =
          (prefs.getInt(_magnetUpgradeKey) ?? 0).clamp(0, maxUpgradeLevel);

      final savedUnlocked = prefs.getStringList(_unlockedShipsKey);
      unlockedShips
        ..clear()
        ..add(ShipType.viper);
      if (savedUnlocked != null) {
        for (final name in savedUnlocked) {
          for (final t in ShipType.values) {
            if (t.name == name) unlockedShips.add(t);
          }
        }
      }

      final savedSelected = prefs.getString(_selectedShipKey);
      if (savedSelected != null) {
        for (final t in ShipType.values) {
          if (t.name == savedSelected && unlockedShips.contains(t)) {
            selectedShip = t;
            previewShip = t;
          }
        }
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_highScoreKey, highScore);
      await prefs.setInt(_coinsKey, coins);
      await prefs.setString(_selectedShipKey, selectedShip.name);
      await prefs.setStringList(
        _unlockedShipsKey,
        unlockedShips.map((e) => e.name).toList(),
      );
      await prefs.setInt(_hullUpgradeKey, hullUpgradeLv);
      await prefs.setInt(_fireUpgradeKey, fireUpgradeLv);
      await prefs.setInt(_magnetUpgradeKey, magnetUpgradeLv);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    sound.isMuted = !sound.isMuted;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, sound.isMuted);
    } catch (_) {}
  }

  void openHangar() {
    previewShip = selectedShip;
    phase = GamePhase.hangar;
    bullets.clear();
    enemies.clear();
    powerUps.clear();
    coinOrbs.clear();
    floatingTexts.clear();
    shockwaves.clear();
    notifyListeners();
  }

  void selectPreviewShip(ShipType type) {
    previewShip = type;
    if (unlockedShips.contains(type)) {
      selectedShip = type;
      _saveProgress();
    }
    sound.playCoin();
    notifyListeners();
  }

  bool unlockOrEquipPreviewShip() {
    if (unlockedShips.contains(previewShip)) {
      selectedShip = previewShip;
      sound.playPowerUp();
      _saveProgress();
      notifyListeners();
      return true;
    }
    final spec = kShipSpecs[previewShip]!;
    if (coins < spec.unlockCost) return false;
    coins -= spec.unlockCost;
    unlockedShips.add(previewShip);
    selectedShip = previewShip;
    sound.playPowerUp();
    _saveProgress();
    notifyListeners();
    return true;
  }

  bool buyHullUpgrade() {
    if (hullUpgradeLv >= maxUpgradeLevel || coins < hullUpgradeCost) {
      return false;
    }
    coins -= hullUpgradeCost;
    hullUpgradeLv += 1;
    sound.playPowerUp();
    _saveProgress();
    notifyListeners();
    return true;
  }

  bool buyFireUpgrade() {
    if (fireUpgradeLv >= maxUpgradeLevel || coins < fireUpgradeCost) {
      return false;
    }
    coins -= fireUpgradeCost;
    fireUpgradeLv += 1;
    sound.playPowerUp();
    _saveProgress();
    notifyListeners();
    return true;
  }

  bool buyMagnetUpgrade() {
    if (magnetUpgradeLv >= maxUpgradeLevel || coins < magnetUpgradeCost) {
      return false;
    }
    coins -= magnetUpgradeCost;
    magnetUpgradeLv += 1;
    sound.playPowerUp();
    _saveProgress();
    notifyListeners();
    return true;
  }

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final bool firstLayout = stars.isEmpty ||
        (viewport.width - size.width).abs() > 2 ||
        (viewport.height - size.height).abs() > 2;
    viewport = size;
    if (firstLayout) {
      _initStars(size);
      if (phase == GamePhase.title || phase == GamePhase.hangar) {
        playerX = size.width * 0.5;
        playerY = size.height * (phase == GamePhase.hangar ? 0.25 : 0.72);
        playerTargetX = playerX;
        playerTargetY = playerY;
      } else {
        playerX = playerX.clamp(28.0, size.width - 28.0);
        playerY = playerY.clamp(90.0, size.height - 60.0);
        playerTargetX = playerX;
        playerTargetY = playerY;
      }
    }
  }

  void _initStars(Size size) {
    stars.clear();
    for (int i = 0; i < 85; i++) {
      final layer = _rng.nextDouble();
      stars.add(
        Star(
          x: _rng.nextDouble() * size.width,
          y: _rng.nextDouble() * size.height,
          speed: 35.0 + layer * 165.0,
          size: 0.9 + layer * 2.1,
          brightness: 0.35 + layer * 0.65,
        ),
      );
    }
  }

  void startGame() {
    final spec = activeShipSpec;
    phase = GamePhase.playing;
    score = 0;
    runCoins = 0;
    wave = 1;
    killsInWave = 0;
    killsForNextWave = 10;
    combo = 0;
    comboTimer = 0.0;
    bossActive = false;

    maxHp = spec.baseHp + hullUpgradeLv;
    hp = maxHp;
    hasShield = true;
    weaponLevel =
        (spec.baseWeaponLevel + (fireUpgradeLv >= 3 ? 1 : 0)).clamp(1, 4);
    final empBonusFromUpgrade =
        (magnetUpgradeLv >= 2 ? 1 : 0) + (magnetUpgradeLv >= 4 ? 1 : 0);
    empCharges = (2 + spec.bonusEmp + empBonusFromUpgrade).clamp(1, 5);
    invulnTimer = 1.0;
    overdriveTimer = 0.0;
    waveBannerTimer = 2.0;

    playerX = viewport.width * 0.5;
    playerY = viewport.height * 0.78;
    playerTargetX = playerX;
    playerTargetY = playerY;
    playerTilt = 0.0;

    bullets.clear();
    enemies.clear();
    particles.clear();
    powerUps.clear();
    coinOrbs.clear();
    floatingTexts.clear();
    shockwaves.clear();

    _fireCooldown = 0.1;
    _spawnTimer = 0.6;
    sound.playPowerUp();
    notifyListeners();
  }

  void togglePause() {
    if (phase == GamePhase.playing) {
      phase = GamePhase.paused;
      notifyListeners();
    } else if (phase == GamePhase.paused) {
      phase = GamePhase.playing;
      notifyListeners();
    }
  }

  void returnToTitle() {
    phase = GamePhase.title;
    bullets.clear();
    enemies.clear();
    powerUps.clear();
    coinOrbs.clear();
    floatingTexts.clear();
    shockwaves.clear();
    playerX = viewport.width * 0.5;
    playerY = viewport.height * 0.72;
    notifyListeners();
  }

  void setTouchPosition(Offset localPos) {
    if (phase != GamePhase.playing) return;
    playerTargetX = localPos.dx.clamp(24.0, viewport.width - 24.0);
    playerTargetY = (localPos.dy - 58.0).clamp(80.0, viewport.height - 44.0);
  }

  void triggerEmp() {
    if (phase != GamePhase.playing || empCharges <= 0) return;
    empCharges -= 1;
    sound.playEmp();
    _addShake(0.45, 11.0);

    shockwaves.add(
      Shockwave(
        x: playerX,
        y: playerY,
        maxRadius: max(viewport.width, viewport.height) * 0.95,
        color: const Color(0xFFFF4081),
        life: 0.55,
      ),
    );

    bullets.removeWhere((b) => !b.isPlayer);

    for (int i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      final dmg = e.type == EnemyType.boss ? 28 : 999;
      e.hp -= dmg;
      e.hitFlash = 0.25;
      _spawnExplosion(e.x, e.y, e.color, count: 10);
      if (e.hp <= 0) {
        _destroyEnemy(i);
      }
    }

    floatingTexts.add(
      FloatingText(
        text: 'EMP SHOCKWAVE!',
        x: playerX,
        y: playerY - 40,
        color: const Color(0xFFFF4081),
        fontSize: 18,
        life: 1.1,
      ),
    );
    notifyListeners();
  }

  void update(double dt) {
    final clampedDt = dt.clamp(0.0, 0.05);
    elapsedTime += clampedDt;

    final bgSpeedMult = phase == GamePhase.playing
        ? (isOverdrive ? 1.85 : 1.0)
        : 0.65;
    gridOffset = (gridOffset + clampedDt * 95.0 * bgSpeedMult) % 48.0;

    for (final s in stars) {
      s.y += s.speed * bgSpeedMult * clampedDt;
      if (s.y > viewport.height + 4) {
        s.y = -4;
        s.x = _rng.nextDouble() * viewport.width;
      }
    }

    if (phase == GamePhase.title) {
      playerX = viewport.width * 0.5 + sin(elapsedTime * 1.4) * 48.0;
      playerY = viewport.height * 0.72 + cos(elapsedTime * 2.1) * 14.0;
      playerTilt = cos(elapsedTime * 1.4) * 0.22;
      _emitThrusterParticles(clampedDt);
      _updateParticles(clampedDt);
      notifyListeners();
      return;
    }

    if (phase == GamePhase.hangar) {
      playerX = viewport.width * 0.5;
      playerY = viewport.height * 0.24 + sin(elapsedTime * 2.6) * 8.0;
      playerTilt = sin(elapsedTime * 1.5) * 0.14;
      _emitThrusterParticles(clampedDt);
      _updateParticles(clampedDt);
      notifyListeners();
      return;
    }

    if (phase != GamePhase.playing) {
      return;
    }

    if (invulnTimer > 0) invulnTimer = max(0.0, invulnTimer - clampedDt);
    if (overdriveTimer > 0) overdriveTimer = max(0.0, overdriveTimer - clampedDt);
    if (waveBannerTimer > 0) waveBannerTimer = max(0.0, waveBannerTimer - clampedDt);
    if (shakeTimer > 0) shakeTimer = max(0.0, shakeTimer - clampedDt);
    if (comboTimer > 0) {
      comboTimer = max(0.0, comboTimer - clampedDt);
      if (comboTimer == 0) combo = 0;
    }

    final spec = activeShipSpec;
    final dx = playerTargetX - playerX;
    final dy = playerTargetY - playerY;
    final follow = (spec.moveFollowSpeed * clampedDt).clamp(0.0, 1.0);
    playerX += dx * follow;
    playerY += dy * follow;
    playerTilt = (dx * 0.015).clamp(-0.38, 0.38);

    _emitThrusterParticles(clampedDt);

    _fireCooldown -= clampedDt;
    if (_fireCooldown <= 0) {
      _firePlayerWeapon();
      final baseRate = (0.19 - (weaponLevel - 1) * 0.015).clamp(0.11, 0.22);
      final upgradeFireMult = 1.0 + fireUpgradeLv * 0.10;
      final totalRateMult = spec.fireRateMult * upgradeFireMult * (isOverdrive ? 1.7 : 1.0);
      _fireCooldown = (baseRate / totalRateMult).clamp(0.065, 0.26);
    }

    if (!bossActive) {
      _spawnTimer -= clampedDt;
      if (_spawnTimer <= 0) {
        _spawnWaveEnemy();
        final interval = (1.05 - wave * 0.055).clamp(0.32, 1.05);
        _spawnTimer = interval * (0.75 + _rng.nextDouble() * 0.5);
      }
    }

    _updateBullets(clampedDt);
    _updateEnemies(clampedDt);
    _updatePowerUps(clampedDt);
    _updateCoinOrbs(clampedDt);
    _updateParticles(clampedDt);
    _updateFloatingTexts(clampedDt);
    _updateShockwaves(clampedDt);

    notifyListeners();
  }

  void _emitThrusterParticles(double dt) {
    _thrusterTimer -= dt;
    if (_thrusterTimer <= 0) {
      _thrusterTimer = 0.025;
      final spec = displayedShipSpec;
      final flameColor = isOverdrive
          ? const Color(0xFFFFD740)
          : spec.secondaryColor;
      final yOffset = phase == GamePhase.hangar ? 28.0 : 18.0;
      particles.add(
        Particle(
          x: playerX + (_rng.nextDouble() - 0.5) * 10,
          y: playerY + yOffset,
          vx: (_rng.nextDouble() - 0.5) * 26,
          vy: 140 + _rng.nextDouble() * 80,
          life: 0.22,
          size: 3.5 + _rng.nextDouble() * 2.5,
          color: flameColor,
        ),
      );
    }
  }

  void _firePlayerWeapon() {
    sound.playLaser();
    final Color boltColor = isOverdrive
        ? const Color(0xFFFFD740)
        : activeShipSpec.primaryColor;
    final int dmg = isOverdrive ? 2 : 1;

    void addBolt(double ox, double oy, double vx, double vy) {
      bullets.add(
        Bullet(
          x: playerX + ox,
          y: playerY + oy,
          vx: vx,
          vy: vy,
          radius: 4.5,
          damage: dmg,
          isPlayer: true,
          color: boltColor,
        ),
      );
    }

    if (weaponLevel == 1) {
      addBolt(0, -24, 0, -680);
    } else if (weaponLevel == 2) {
      addBolt(-11, -16, 0, -700);
      addBolt(11, -16, 0, -700);
    } else if (weaponLevel == 3) {
      addBolt(0, -24, 0, -720);
      addBolt(-13, -14, -95, -690);
      addBolt(13, -14, 95, -690);
    } else {
      addBolt(0, -26, 0, -740);
      addBolt(-11, -18, -55, -720);
      addBolt(11, -18, 55, -720);
      addBolt(-18, -10, -155, -680);
      addBolt(18, -10, 155, -680);
    }
  }

  void _spawnWaveEnemy() {
    final roll = _rng.nextDouble();
    final margin = 36.0;
    final x = margin + _rng.nextDouble() * max(40.0, viewport.width - margin * 2);

    if (roll < 0.52) {
      enemies.add(
        Enemy(
          type: EnemyType.scout,
          x: x,
          y: -26,
          vx: 0,
          vy: 155 + wave * 11 + _rng.nextDouble() * 45,
          radius: 17,
          hp: 1 + (wave ~/ 4),
          scoreValue: 100,
          color: const Color(0xFFFF3D71),
          weavePhase: _rng.nextDouble() * pi * 2,
        ),
      );
    } else if (roll < 0.82) {
      enemies.add(
        Enemy(
          type: EnemyType.striker,
          x: x,
          y: -30,
          vx: (_rng.nextBool() ? 1 : -1) * (45 + _rng.nextDouble() * 35),
          vy: 95 + wave * 7,
          radius: 21,
          hp: 3 + (wave ~/ 2),
          scoreValue: 220,
          color: const Color(0xFFFF9100),
          fireTimer: 0.9 + _rng.nextDouble() * 0.9,
        ),
      );
    } else {
      enemies.add(
        Enemy(
          type: EnemyType.cruiser,
          x: x,
          y: -38,
          vx: 0,
          vy: 62 + wave * 4,
          radius: 29,
          hp: 7 + wave * 2,
          scoreValue: 450,
          color: const Color(0xFFD500F9),
          fireTimer: 1.4,
        ),
      );
    }
  }

  void _spawnBoss() {
    bossActive = true;
    final bossHp = 55 + wave * 18;
    enemies.add(
      Enemy(
        type: EnemyType.boss,
        x: viewport.width * 0.5,
        y: -75,
        vx: 85 + wave * 5,
        vy: 55,
        radius: 52,
        hp: bossHp,
        scoreValue: 2500 + wave * 400,
        color: const Color(0xFFFF1744),
        fireTimer: 1.1,
      ),
    );
    waveBannerTimer = 2.4;
    floatingTexts.add(
      FloatingText(
        text: 'WARNING: BOSS DREADNOUGHT!',
        x: viewport.width * 0.5,
        y: viewport.height * 0.34,
        color: const Color(0xFFFF1744),
        fontSize: 19,
        life: 1.8,
      ),
    );
    _addShake(0.35, 7.0);
  }

  void _updateBullets(double dt) {
    for (int i = bullets.length - 1; i >= 0; i--) {
      final b = bullets[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      if (b.y < -30 ||
          b.y > viewport.height + 30 ||
          b.x < -30 ||
          b.x > viewport.width + 30) {
        bullets.removeAt(i);
        continue;
      }

      if (b.isPlayer) {
        bool hit = false;
        for (int j = enemies.length - 1; j >= 0; j--) {
          final e = enemies[j];
          final dx = b.x - e.x;
          final dy = b.y - e.y;
          final minDist = b.radius + e.radius;
          if (dx * dx + dy * dy <= minDist * minDist) {
            e.hp -= b.damage;
            e.hitFlash = 0.1;
            _spawnExplosion(b.x, b.y, b.color, count: 4, speed: 95);
            hit = true;
            if (e.hp <= 0) {
              _destroyEnemy(j);
            }
            break;
          }
        }
        if (hit) bullets.removeAt(i);
      } else {
        final dx = b.x - playerX;
        final dy = b.y - playerY;
        final minDist = b.radius + playerRadius * 0.8;
        if (dx * dx + dy * dy <= minDist * minDist) {
          bullets.removeAt(i);
          _damagePlayer();
        }
      }
    }
  }

  void _updateEnemies(double dt) {
    for (int i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      e.age += dt;
      if (e.hitFlash > 0) e.hitFlash = max(0.0, e.hitFlash - dt);

      if (e.type == EnemyType.scout) {
        e.x += sin(e.age * 4.2 + e.weavePhase) * 95 * dt;
        e.y += e.vy * dt;
      } else if (e.type == EnemyType.striker) {
        e.x += e.vx * dt;
        e.y += e.vy * dt;
        if (e.x < e.radius + 8 || e.x > viewport.width - e.radius - 8) {
          e.vx = -e.vx;
        }
        e.fireTimer -= dt;
        if (e.fireTimer <= 0 && e.y > 30 && e.y < viewport.height * 0.68) {
          _fireEnemyAimedShot(e, 260 + wave * 12);
          e.fireTimer = max(0.95, 2.0 - wave * 0.06);
        }
      } else if (e.type == EnemyType.cruiser) {
        e.y += e.vy * dt;
        e.fireTimer -= dt;
        if (e.fireTimer <= 0 && e.y > 40 && e.y < viewport.height * 0.65) {
          for (final angle in [-0.28, 0.0, 0.28]) {
            bullets.add(
              Bullet(
                x: e.x,
                y: e.y + e.radius * 0.6,
                vx: sin(angle) * 230,
                vy: cos(angle) * 230,
                radius: 5.5,
                damage: 1,
                isPlayer: false,
                color: const Color(0xFFE040FB),
              ),
            );
          }
          e.fireTimer = max(1.3, 2.4 - wave * 0.05);
        }
      } else if (e.type == EnemyType.boss) {
        if (e.y < 125) {
          e.y += e.vy * dt;
        } else {
          e.x += e.vx * dt;
          if (e.x < e.radius + 16) {
            e.x = e.radius + 16;
            e.vx = e.vx.abs();
          } else if (e.x > viewport.width - e.radius - 16) {
            e.x = viewport.width - e.radius - 16;
            e.vx = -e.vx.abs();
          }

          e.fireTimer -= dt;
          if (e.fireTimer <= 0) {
            for (int k = -2; k <= 2; k++) {
              final angle = k * 0.22 + sin(e.age * 1.5) * 0.12;
              bullets.add(
                Bullet(
                  x: e.x + k * 14,
                  y: e.y + 30,
                  vx: sin(angle) * 255,
                  vy: cos(angle) * 255,
                  radius: 6.0,
                  damage: 1,
                  isPlayer: false,
                  color: const Color(0xFFFF5252),
                ),
              );
            }
            e.fireTimer = max(0.7, 1.35 - wave * 0.04);
          }
        }
      }

      e.x = e.x.clamp(e.radius + 4, viewport.width - e.radius - 4);

      if (e.type != EnemyType.boss && e.y > viewport.height + 50) {
        enemies.removeAt(i);
        continue;
      }

      final dx = e.x - playerX;
      final dy = e.y - playerY;
      final minDist = e.radius + playerRadius * 0.85;
      if (dx * dx + dy * dy <= minDist * minDist) {
        if (e.type != EnemyType.boss) {
          _spawnExplosion(e.x, e.y, e.color, count: 16);
          enemies.removeAt(i);
        }
        _damagePlayer();
      }
    }
  }

  void _fireEnemyAimedShot(Enemy e, double speed) {
    final dx = playerX - e.x;
    final dy = playerY - e.y;
    final dist = max(1.0, sqrt(dx * dx + dy * dy));
    bullets.add(
      Bullet(
        x: e.x,
        y: e.y + e.radius * 0.5,
        vx: (dx / dist) * speed,
        vy: (dy / dist) * speed,
        radius: 5.0,
        damage: 1,
        isPlayer: false,
        color: const Color(0xFFFFAB40),
      ),
    );
  }

  void _destroyEnemy(int index) {
    final e = enemies.removeAt(index);
    final isBoss = e.type == EnemyType.boss;

    combo += 1;
    comboTimer = 2.8;
    final comboMult = (1.0 + min(combo, 15) * 0.1) * (isOverdrive ? 2.0 : 1.0);
    final gained = (e.scoreValue * comboMult).round();
    score += gained;
    if (score > highScore) {
      highScore = score;
    }

    sound.playExplosion(heavy: isBoss || e.type == EnemyType.cruiser);
    _spawnExplosion(
      e.x,
      e.y,
      e.color,
      count: isBoss ? 48 : (e.type == EnemyType.cruiser ? 26 : 16),
      speed: isBoss ? 280 : 190,
    );

    // Spawn collectible gold coin orbs
    final int coinCount = isBoss
        ? 10
        : (e.type == EnemyType.cruiser ? 3 : (e.type == EnemyType.striker ? 2 : 1));
    final int coinVal = isBoss ? 15 : (e.type == EnemyType.cruiser ? 8 : 5);
    for (int c = 0; c < coinCount; c++) {
      coinOrbs.add(
        CoinOrb(
          x: e.x + (_rng.nextDouble() - 0.5) * 28,
          y: e.y + (_rng.nextDouble() - 0.5) * 20,
          vx: (_rng.nextDouble() - 0.5) * 85,
          vy: 75 + _rng.nextDouble() * 65,
          value: (coinVal * activeShipSpec.coinMult).round(),
        ),
      );
    }

    if (isBoss) {
      bossActive = false;
      _addShake(0.55, 13.0);
      shockwaves.add(
        Shockwave(
          x: e.x,
          y: e.y,
          maxRadius: 240,
          color: const Color(0xFFFFB300),
          life: 0.6,
        ),
      );
      _dropPowerUp(e.x - 24, e.y, forced: PowerUpType.spread);
      _dropPowerUp(e.x + 24, e.y, forced: PowerUpType.emp);
      _advanceWave();
    } else {
      final dropChance = e.type == EnemyType.cruiser ? 0.45 : 0.13;
      if (_rng.nextDouble() < dropChance) {
        _dropPowerUp(e.x, e.y);
      }
      killsInWave += 1;
      if (killsInWave >= killsForNextWave && !bossActive) {
        _advanceWave();
      }
    }

    floatingTexts.add(
      FloatingText(
        text: '+$gained',
        x: e.x,
        y: e.y - 10,
        color: isBoss ? const Color(0xFFFFD740) : e.color,
        fontSize: isBoss ? 20 : 13.5,
      ),
    );
  }

  void _advanceWave() {
    wave += 1;
    killsInWave = 0;
    killsForNextWave = 10 + wave * 3;
    waveBannerTimer = 2.0;
    _saveProgress();

    if (wave % 4 == 0) {
      _spawnBoss();
    }
  }

  void _dropPowerUp(double x, double y, {PowerUpType? forced}) {
    final type = forced ?? _pickRandomPowerUp();
    powerUps.add(PowerUp(type: type, x: x, y: y));
  }

  PowerUpType _pickRandomPowerUp() {
    final r = _rng.nextDouble();
    if (r < 0.36) return PowerUpType.spread;
    if (r < 0.64) return PowerUpType.shield;
    if (r < 0.86) return PowerUpType.overdrive;
    return PowerUpType.emp;
  }

  void _updatePowerUps(double dt) {
    for (int i = powerUps.length - 1; i >= 0; i--) {
      final p = powerUps[i];
      p.age += dt;
      p.y += p.vy * dt;

      if (p.y > viewport.height + 30) {
        powerUps.removeAt(i);
        continue;
      }

      final dx = p.x - playerX;
      final dy = p.y - playerY;
      final minDist = p.radius + playerRadius + 10;
      if (dx * dx + dy * dy <= minDist * minDist) {
        powerUps.removeAt(i);
        _applyPowerUp(p);
      }
    }
  }

  void _updateCoinOrbs(double dt) {
    final magR = coinMagnetRadius;
    final magR2 = magR * magR;

    for (int i = coinOrbs.length - 1; i >= 0; i--) {
      final c = coinOrbs[i];
      c.age += dt;

      final dx = playerX - c.x;
      final dy = playerY - c.y;
      final d2 = dx * dx + dy * dy;

      if (d2 <= magR2) {
        final dist = max(1.0, sqrt(d2));
        final pull = 440.0 + magnetUpgradeLv * 55.0;
        c.vx = (dx / dist) * pull;
        c.vy = (dy / dist) * pull;
      } else {
        c.vx *= 0.96;
        c.vy = min(145.0, c.vy + 40.0 * dt);
      }

      c.x += c.vx * dt;
      c.y += c.vy * dt;

      if (d2 <= (playerRadius + 14) * (playerRadius + 14)) {
        coinOrbs.removeAt(i);
        coins += c.value;
        runCoins += c.value;
        sound.playCoin();
        continue;
      }

      if (c.y > viewport.height + 30) {
        coinOrbs.removeAt(i);
      }
    }
  }

  void _applyPowerUp(PowerUp p) {
    sound.playPowerUp();
    String msg;
    switch (p.type) {
      case PowerUpType.spread:
        if (weaponLevel < 4) {
          weaponLevel += 1;
          msg = 'WEAPON LV.$weaponLevel!';
        } else {
          score += 500;
          msg = 'MAX WEAPON +500';
        }
        break;
      case PowerUpType.shield:
        if (!hasShield) {
          hasShield = true;
          msg = 'SHIELD ONLINE!';
        } else if (hp < maxHp) {
          hp += 1;
          msg = '+1 HULL REPAIR!';
        } else {
          score += 400;
          msg = 'SHIELD +400';
        }
        break;
      case PowerUpType.overdrive:
        overdriveTimer = 8.0;
        msg = '2X OVERDRIVE!';
        break;
      case PowerUpType.emp:
        empCharges = min(5, empCharges + 1);
        msg = '+1 EMP CHARGE!';
        break;
    }

    floatingTexts.add(
      FloatingText(
        text: msg,
        x: playerX,
        y: playerY - 32,
        color: p.color,
        fontSize: 15,
        life: 1.0,
      ),
    );
  }

  void _damagePlayer() {
    if (invulnTimer > 0) return;

    if (hasShield) {
      hasShield = false;
      invulnTimer = 1.2;
      sound.playHit();
      _addShake(0.25, 7.0);
      shockwaves.add(
        Shockwave(
          x: playerX,
          y: playerY,
          maxRadius: 95,
          color: const Color(0xFF00E676),
          life: 0.35,
        ),
      );
      floatingTexts.add(
        FloatingText(
          text: 'SHIELD BROKEN!',
          x: playerX,
          y: playerY - 28,
          color: const Color(0xFF00E676),
          fontSize: 14,
        ),
      );
      return;
    }

    hp -= 1;
    combo = 0;
    invulnTimer = 1.6;
    sound.playHit();
    _addShake(0.35, 10.0);
    _spawnExplosion(playerX, playerY, activeShipSpec.primaryColor, count: 22);

    if (weaponLevel > 1) {
      weaponLevel -= 1;
    }

    if (hp <= 0) {
      phase = GamePhase.gameOver;
      sound.playExplosion(heavy: true);
      _spawnExplosion(playerX, playerY, const Color(0xFFFF4081), count: 45, speed: 260);
      if (score > highScore) {
        highScore = score;
      }
      _saveProgress();
    }
  }

  void _spawnExplosion(
    double x,
    double y,
    Color color, {
    int count = 16,
    double speed = 180,
  }) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final spd = speed * (0.25 + _rng.nextDouble() * 0.85);
      particles.add(
        Particle(
          x: x,
          y: y,
          vx: cos(angle) * spd,
          vy: sin(angle) * spd,
          life: 0.25 + _rng.nextDouble() * 0.35,
          size: 2.0 + _rng.nextDouble() * 3.8,
          color: i % 3 == 0 ? Colors.white : color,
        ),
      );
    }
  }

  void _addShake(double duration, double intensity) {
    shakeTimer = max(shakeTimer, duration);
    shakeIntensity = max(shakeIntensity, intensity);
  }

  void _updateParticles(double dt) {
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.96;
      p.vy *= 0.96;
    }
  }

  void _updateFloatingTexts(double dt) {
    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      final f = floatingTexts[i];
      f.life -= dt;
      if (f.life <= 0) {
        floatingTexts.removeAt(i);
        continue;
      }
      f.y += f.vy * dt;
    }
  }

  void _updateShockwaves(double dt) {
    for (int i = shockwaves.length - 1; i >= 0; i--) {
      final s = shockwaves[i];
      s.life -= dt;
      if (s.life <= 0) {
        shockwaves.removeAt(i);
        continue;
      }
      final t = 1.0 - (s.life / s.maxLife);
      s.radius = 12.0 + (s.maxRadius - 12.0) * t;
    }
  }

  @override
  void dispose() {
    sound.dispose();
    super.dispose();
  }
}
