import 'package:flutter_test/flutter_test.dart';
import 'package:walkwin_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ExploriaApp());
    expect(find.byType(ExploriaApp), findsOneWidget);
  });
}
