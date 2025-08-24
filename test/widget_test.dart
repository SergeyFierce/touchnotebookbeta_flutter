import 'package:flutter_test/flutter_test.dart';

import 'package:touchnotebookbeta_flutter/app.dart';

void main() {
  testWidgets('Home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Touch NoteBook'), findsOneWidget);
  });
}

