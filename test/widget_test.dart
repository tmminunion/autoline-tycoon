import 'package:autoline_tycoon/main.dart';
import 'package:autoline_tycoon/services/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GameController upgrades speed and boosts stations', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = GameController();
    await controller.init();

    final startCash = controller.cash;
    final upgraded = controller.upgradeSpeed(0);
    expect(upgraded, isTrue);
    expect(controller.stations[0].speedLevel, equals(2));
    expect(controller.cash, lessThan(startCash));

    controller.tapBoostStation(0);
    expect(controller.stations[0].progress, greaterThan(0));

    controller.dispose();
  });

  testWidgets('AutoLineTycoonApp renders factory dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AutoLineTycoonApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AUTOLINE TYCOON'), findsOneWidget);
    expect(find.text('Stamping Press'), findsOneWidget);
    expect(find.text('PRODUCTION LINE STATIONS'), findsOneWidget);

    // Unmount widget so periodic timers are disposed cleanly
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
