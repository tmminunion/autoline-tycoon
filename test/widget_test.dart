import 'package:autoline_tycoon/main.dart';
import 'package:autoline_tycoon/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GameState simulation produces units and cash', () {
    final state = GameState.initial();
    final startCash = state.cash;

    // Simulate 30 seconds of production
    for (var i = 0; i < 300; i++) {
      state.tick(0.1);
    }

    expect(state.unitsProduced, greaterThan(0));
    expect(state.cash, greaterThan(startCash));
  });

  testWidgets('AutoLineTycoonApp renders home dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AutoLineTycoonApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AUTOLINE TYCOON'), findsOneWidget);
    expect(find.text('1. Stamping Press'), findsOneWidget);
    expect(find.text('Lini Produksi'), findsOneWidget);
  });
}
