import 'package:autoline_tycoon/game/entities.dart';
import 'package:autoline_tycoon/game/game_engine.dart';
import 'package:autoline_tycoon/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ArcadeGameEngine starts mission, fires lasers, and triggers EMP', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final engine = ArcadeGameEngine();
    engine.sound.isMuted = true; // Disable native audio plugin in headless tests
    engine.setViewport(const Size(400, 800));
    engine.startGame();

    expect(engine.phase, equals(GamePhase.playing));
    expect(engine.empCharges, equals(2));

    // Simulate 1 second of 60 FPS gameplay
    for (int i = 0; i < 60; i++) {
      engine.update(1 / 60);
    }

    expect(engine.bullets.any((b) => b.isPlayer), isTrue);

    engine.triggerEmp();
    expect(engine.empCharges, equals(1));
    expect(engine.shockwaves.isNotEmpty, isTrue);

    engine.dispose();
  });

  testWidgets('NeonStrikerApp renders full-screen arcade title screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NeonStrikerApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('STRIKER'), findsOneWidget);
    expect(find.text('LAUNCH MISSION'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
