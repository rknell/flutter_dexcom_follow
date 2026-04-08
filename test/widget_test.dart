// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dexcom_follow/main.dart';

void main() {
  testWidgets('FEATURE: app boots to login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const DexcomFollowApp());
    await tester.pumpAndSettle();
    expect(find.text('Dexcom Follow'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
