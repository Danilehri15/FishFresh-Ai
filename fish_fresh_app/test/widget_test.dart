// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fish_fresh_app/main.dart';
import 'package:fish_fresh_app/data/repositories/app_provider.dart';

void main() {
  testWidgets('FishFreshApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ],
        child: const FishFreshApp(),
      ),
    );

    expect(find.text('FishFresh AI'), findsWidgets);
  });
}
