import 'package:autoline_tycoon/game/entities.dart';
import 'package:autoline_tycoon/game/game_engine.dart';
import 'package:autoline_tycoon/games/neon_dash/dash_engine.dart';
import 'package:autoline_tycoon/main.dart';
import 'package:autoline_tycoon/services/remote_games_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ArcadeGameEngine starts mission, fires lasers, and triggers EMP', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final engine = ArcadeGameEngine();
    engine.sound.isMuted = true;
    engine.setViewport(const Size(400, 800));
    engine.startGame();

    expect(engine.phase, equals(GamePhase.playing));
    expect(engine.empCharges, equals(2));

    for (int i = 0; i < 60; i++) {
      engine.update(1 / 60);
    }

    expect(engine.bullets.any((b) => b.isPlayer), isTrue);

    engine.triggerEmp();
    expect(engine.empCharges, equals(1));
    expect(engine.shockwaves.isNotEmpty, isTrue);

    engine.dispose();
  });

  test('Hangar unlocks fighter ship and buys permanent upgrades with coins', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final engine = ArcadeGameEngine();
    engine.sound.isMuted = true;
    engine.coins = 1000;

    engine.openHangar();
    engine.selectPreviewShip(ShipType.phantom);
    expect(engine.isShipUnlocked(ShipType.phantom), isFalse);
    expect(engine.unlockOrEquipPreviewShip(), isTrue);
    expect(engine.isShipUnlocked(ShipType.phantom), isTrue);
    expect(engine.selectedShip, equals(ShipType.phantom));
    expect(engine.coins, equals(650));

    expect(engine.buyHullUpgrade(), isTrue);
    expect(engine.hullUpgradeLv, equals(1));
    expect(engine.buyFireUpgrade(), isTrue);
    expect(engine.fireUpgradeLv, equals(1));

    engine.startGame();
    expect(engine.maxHp, equals(3));

    engine.dispose();
  });

  test('DashEngine supports double jump, slide, and shield collision protection', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final dash = DashEngine();
    dash.setViewport(const Size(400, 800));
    dash.startGame();

    expect(dash.phase, equals(DashPhase.playing));
    dash.jump();
    expect(dash.jumpsUsed, equals(1));
    dash.jump();
    expect(dash.jumpsUsed, equals(2));

    dash.slide();
    expect(dash.sliding, isTrue);

    dash.hasShield = true;
    dash.obstacles.add(
      DashObstacle(
        type: DashObstacleType.crate,
        x: dash.playerX + 10,
        y: dash.playerY + 5,
        w: 44,
        h: 44,
      ),
    );
    dash.update(1 / 60);
    expect(dash.hasShield, isFalse);
    expect(dash.phase, equals(DashPhase.playing));

    dash.dispose();
  });

  test('RemoteGamesService parses API catalog and filters active HTTPS games', () {
    const raw = '''
    {
      "version": 1,
      "games": [
        {"id": "neon-stack", "title": "NEON STACK", "url": "https://nufat.id/games/neon-stack/", "active": true},
        {"id": "off-game", "title": "OFF", "url": "https://nufat.id/games/off/", "active": false},
        {"id": "bad-http", "title": "BAD", "url": "http://insecure.local/game", "active": true}
      ]
    }
    ''';
    final parsed = RemoteGamesService.parseCatalog(raw);
    expect(parsed.length, 1);
    expect(parsed.first.id, 'neon-stack');
    expect(parsed.first.title, 'NEON STACK');
  });

  testWidgets('NufatGamesApp renders Hybrid Hub (Native + WebView) and launches Neon Striker',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NufatGamesApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NUFAT GAMES'), findsOneWidget);
    expect(find.text('NEON STRIKER'), findsOneWidget);
    expect(find.text('NEON DASH'), findsOneWidget);
    expect(find.text('NEON STACK'), findsOneWidget);

    await tester.tap(find.text('NEON STRIKER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('STRIKER'), findsOneWidget);
    expect(find.text('HANGAR & UPGRADES'), findsOneWidget);

    await tester.tap(find.text('HANGAR & UPGRADES'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('STARFIGHTER HANGAR'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
