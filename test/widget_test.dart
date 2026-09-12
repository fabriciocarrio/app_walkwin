import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkwin_app/widgets/holographic_card_widget.dart';

void main() {
  testWidgets('HolographicCardWidget renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HolographicCardWidget(
            title: 'Tarjeta Test',
            rarity: 'legendary',
            isHolographic: true,
          ),
        ),
      ),
    );

    expect(find.text('Tarjeta Test'), findsOneWidget);
    expect(find.text('LEGENDARIA'), findsOneWidget);
  });
}
