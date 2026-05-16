import 'package:flutter_test/flutter_test.dart';
import 'package:scoreboard_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScoreboardApp());
    expect(find.byType(ScoreboardApp), findsOneWidget);
  });
}
