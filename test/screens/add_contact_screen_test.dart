import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overlay_support/overlay_support.dart';

import 'package:touchnotebookbeta_flutter/screens/add_contact_screen.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';
import 'package:touchnotebookbeta_flutter/models/contact.dart';

class MockContactDatabase extends Mock implements ContactDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockContactDatabase mockDb;
  late ContactDatabase realDb;

  setUp(() {
    mockDb = MockContactDatabase();
    realDb = ContactDatabase.instance;
    ContactDatabase.instance = mockDb;

    when(() => mockDb.contactByPhone(any(), excludeId: any(named: 'excludeId')))
        .thenAnswer((_) async => null);
    when(() => mockDb.contactByPhone(any())).thenAnswer((_) async => null);
    when(() => mockDb.insert(any())).thenAnswer((_) async => 42);
  });

  tearDown(() {
    ContactDatabase.instance = realDb;
  });

  testWidgets('saving a valid contact triggers insert and closes screen',
      (tester) async {
    await tester.pumpWidget(
      OverlaySupport.global(
        child: const MaterialApp(
          home: AddContactScreen(category: 'Клиент'),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ФИО*'),
      'Иван Иванов',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон*'),
      '9123456789',
    );

    await tester.tap(find.widgetWithText(TextFormField, 'Статус*'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Активный').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    verify(
      () => mockDb.insert(
        any(that: isA<Contact>().having((c) => c.phone, 'phone', '9123456789')),
      ),
    ).called(1);
    expect(find.byType(AddContactScreen), findsNothing);
  });
}
