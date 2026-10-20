// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:cueflow/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CueFlowApp());
    expect(find.text('CueFlow'), findsOneWidget);
  });
}