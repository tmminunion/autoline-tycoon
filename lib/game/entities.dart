import 'package:flutter/material.dart';

enum GamePhase { title, hangar, playing, paused, gameOver }

enum ShipType { viper, phantom, titan }

enum EnemyType { scout, striker, cruiser, boss }

enum PowerUpType { spread, shield, overdrive, emp }

class ShipSpec {
  final ShipType type;
  final String name;
  final String role;
  final Color primaryColor;
  final Color secondaryColor;
  final int baseHp;
  final double fireRateMult; // higher = faster fire
  final double moveFollowSpeed; // responsiveness
  final int baseWeaponLevel;
  final int bonusEmp;
  final double coinMult;
  final int unlockCost;

  const ShipSpec({
    required this.type,
    required this.name,
    required this.role,
    required this.primaryColor,
    required this.secondaryColor,
    required this.baseHp,
    required this.fireRateMult,
    required this.moveFollowSpeed,
    required this.baseWeaponLevel,
    required this.bonusEmp,
    required this.coinMult,
    required this.unlockCost,
  });
}

const Map<ShipType, ShipSpec> kShipSpecs = {
  ShipType.viper: ShipSpec(
    type: ShipType.viper,
    name: 'VIPER-X',
    role: 'BALANCED INTERCEPTOR',
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFFFF4081),
    baseHp: 3,
    fireRateMult: 1.0,
    moveFollowSpeed: 18.0,
    baseWeaponLevel: 1,
    bonusEmp: 0,
    coinMult: 1.0,
    unlockCost: 0,
  ),
  ShipType.phantom: ShipSpec(
    type: ShipType.phantom,
    name: 'PHANTOM-9',
    role: 'RAPID STEALTH STRIKER',
    primaryColor: Color(0xFFFF4081),
    secondaryColor: Color(0xFFD500F9),
    baseHp: 2,
    fireRateMult: 1.32,
    moveFollowSpeed: 24.0,
    baseWeaponLevel: 1,
    bonusEmp: 0,
    coinMult: 1.35,
    unlockCost: 350,
  ),
  ShipType.titan: ShipSpec(
    type: ShipType.titan,
    name: 'TITAN-MK4',
    role: 'HEAVY ARMORED GUNSHIP',
    primaryColor: Color(0xFFFFB300),
    secondaryColor: Color(0xFF00E676),
    baseHp: 5,
    fireRateMult: 0.92,
    moveFollowSpeed: 14.5,
    baseWeaponLevel: 2,
    bonusEmp: 1,
    coinMult: 1.15,
    unlockCost: 750,
  ),
};

class Star {
  double x;
  double y;
  double speed;
  double size;
  double brightness;

  Star({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.brightness,
  });
}

class Bullet {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  int damage;
  bool isPlayer;
  Color color;

  Bullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.damage,
    required this.isPlayer,
    required this.color,
  });
}

class Enemy {
  EnemyType type;
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  int hp;
  int maxHp;
  int scoreValue;
  Color color;
  double fireTimer;
  double age;
  double hitFlash;
  double weavePhase;

  Enemy({
    required this.type,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.hp,
    required this.scoreValue,
    required this.color,
    this.fireTimer = 1.2,
    this.age = 0.0,
    this.hitFlash = 0.0,
    this.weavePhase = 0.0,
  }) : maxHp = hp;
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double maxLife;
  double size;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
  }) : maxLife = life;
}

class PowerUp {
  PowerUpType type;
  double x;
  double y;
  double vy;
  double radius;
  double age;

  PowerUp({
    required this.type,
    required this.x,
    required this.y,
    this.vy = 115.0,
    this.radius = 16.0,
    this.age = 0.0,
  });

  Color get color {
    switch (type) {
      case PowerUpType.spread:
        return const Color(0xFF00E5FF);
      case PowerUpType.shield:
        return const Color(0xFF00E676);
      case PowerUpType.overdrive:
        return const Color(0xFFFFB300);
      case PowerUpType.emp:
        return const Color(0xFFFF4081);
    }
  }

  String get shortLabel {
    switch (type) {
      case PowerUpType.spread:
        return 'W';
      case PowerUpType.shield:
        return 'S';
      case PowerUpType.overdrive:
        return '2X';
      case PowerUpType.emp:
        return 'E';
    }
  }
}

class CoinOrb {
  double x;
  double y;
  double vx;
  double vy;
  int value;
  double age;

  CoinOrb({
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 105.0,
    this.value = 5,
    this.age = 0.0,
  });
}

class FloatingText {
  String text;
  double x;
  double y;
  double vy;
  double life;
  double maxLife;
  Color color;
  double fontSize;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.vy = -52.0,
    this.life = 0.9,
    required this.color,
    this.fontSize = 14.0,
  }) : maxLife = life;
}

class Shockwave {
  double x;
  double y;
  double radius;
  double maxRadius;
  Color color;
  double life;
  double maxLife;

  Shockwave({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.color,
    this.life = 0.5,
  })  : radius = 12.0,
        maxLife = life;
}
