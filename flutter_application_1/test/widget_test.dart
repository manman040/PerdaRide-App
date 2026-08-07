// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:perdaride/app/app.dart';

void main() {
  testWidgets('PerdaRide app loads splash screen', (tester) async {
    await tester.pumpWidget(const PerdaRideApp());

    expect(find.text('PerdaRide'), findsOneWidget);
    expect(find.text('Passenger and driver services in one app.'), findsOneWidget);
  });
}
