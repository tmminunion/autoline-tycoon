import 'package:flutter/material.dart';

enum GamePhase { title, playing, paused, gameOver }

enum EnemyType { scout, striker, cruiser, boss }

enum PowerUpType { spread, shield, overdrive, emp }

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
