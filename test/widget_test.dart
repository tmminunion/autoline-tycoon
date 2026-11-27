import 'package:autoline_tycoon/game/entities.dart';
import 'package:autoline_tycoon/game/game_engine.dart';
import 'package:autoline_tycoon/main.dart';
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

    // Unlock Phantom-9 (350 coins)
    engine.openHangar();
    engine.selectPreviewShip(ShipType.phantom);
    expect(engine.isShipUnlocked(ShipType.phantom), isFalse);
    expect(engine.unlockOrEquipPreviewShip(), isTrue);
    expect(engine.isShipUnlocked(ShipType.phantom), isTrue);
    expect(engine.selectedShip, equals(ShipType.phantom));
    expect(engine.coins, equals(650));

    // Buy Hull & Fire permanent upgrades
    expect(engine.buyHullUpgrade(), isTrue);
    expect(engine.hullUpgradeLv, equals(1));
    expect(engine.buyFireUpgrade(), isTrue);
    expect(engine.fireUpgradeLv, equals(1));

    // Start game and verify Hull upgrade applied to Phantom-9 (base 2 + 1 = 3)
    engine.startGame();
    expect(engine.maxHp, equals(3));

    engine.dispose();
  });

  testWidgets('NeonStrikerApp renders title screen and navigates to Hangar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NeonStrikerApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('STRIKER'), findsOneWidget);
    expect(find.text('HANGAR & UPGRADES'), findsOneWidget);

    await tester.tap(find.text('HANGAR & UPGRADES'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('STARFIGHTER HANGAR'), findsOneWidget);
    expect(find.text('VIPER-X'), findsOneWidget);
    expect(find.text('PHANTOM-9'), findsOneWidget);
    expect(find.text('TITAN-MK4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
