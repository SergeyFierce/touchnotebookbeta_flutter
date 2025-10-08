import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overlay_support/overlay_support.dart';

import 'package:touchnotebookbeta_flutter/models/contact.dart';
import 'package:touchnotebookbeta_flutter/models/note.dart';
import 'package:touchnotebookbeta_flutter/models/reminder.dart';
import 'package:touchnotebookbeta_flutter/screens/contact_details_screen.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';
import 'package:touchnotebookbeta_flutter/services/push_notifications.dart';

class MockContactDatabase extends Mock implements ContactDatabase {}

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockContactDatabase mockDb;
  late ContactDatabase realDb;
  late MockFlutterLocalNotificationsPlugin mockPlugin;

  final contact = Contact(
    id: 1,
    name: 'Иван Иванов',
    phone: '1234567890',
    category: 'Клиент',
    status: 'Активный',
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockDb = MockContactDatabase();
    realDb = ContactDatabase.instance;
    ContactDatabase.instance = mockDb;

    mockPlugin = MockFlutterLocalNotificationsPlugin();
    when(() => mockPlugin.cancel(any())).thenAnswer((_) async => true);
    when(() => mockPlugin.cancelAll()).thenAnswer((_) async => true);
    PushNotifications.resetForTests(plugin: mockPlugin);

    when(() => mockDb.contactByPhone(any(), excludeId: any(named: 'excludeId')))
        .thenAnswer((_) async => null);
    when(() => mockDb.update(any())).thenAnswer((_) async => 1);
    when(() => mockDb.deleteContactWithSnapshot(any())).thenAnswer(
      (_) async => (notes: <Note>[], reminders: <Reminder>[]),
    );
    when(() => mockDb.completeDueRemindersForContact(any()))
        .thenAnswer((_) async => []);
    when(
      () => mockDb.remindersByContact(
        any(),
        onlyActive: any(named: 'onlyActive'),
        onlyCompleted: any(named: 'onlyCompleted'),
      ),
    ).thenAnswer((_) async => []);
    when(() => mockDb.lastNotesByContact(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    ContactDatabase.instance = realDb;
    PushNotifications.resetForTests();
  });

  testWidgets('editing contact updates database and closes screen',
      (tester) async {
    await tester.pumpWidget(
      OverlaySupport.global(
        child: MaterialApp(
          home: ContactDetailsScreen(contact: contact),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ФИО*'),
      'Иван Петров',
    );
    await tester.pump();

    final saveButton =
        find.widgetWithText(FloatingActionButton, 'Сохранить');
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(
      () => mockDb.update(
        any(that: isA<Contact>().having((c) => c.name, 'name', 'Иван Петров')),
      ),
    ).called(1);
    expect(find.byType(ContactDetailsScreen), findsNothing);
  });

  testWidgets('delete contact calls database and pops screen', (tester) async {
    await tester.pumpWidget(
      OverlaySupport.global(
        child: MaterialApp(
          home: ContactDetailsScreen(contact: contact),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить контакт'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    verify(() => mockDb.deleteContactWithSnapshot(contact.id!)).called(1);
    expect(find.byType(ContactDetailsScreen), findsNothing);
  });
}
