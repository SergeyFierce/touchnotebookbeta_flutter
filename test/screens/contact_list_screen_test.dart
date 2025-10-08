import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overlay_support/overlay_support.dart';

import 'package:touchnotebookbeta_flutter/models/contact.dart';
import 'package:touchnotebookbeta_flutter/screens/contact_list_screen.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';

class MockContactDatabase extends Mock implements ContactDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockContactDatabase mockDb;
  late ContactDatabase realDb;
  late ValueNotifier<int> revision;

  setUp(() {
    mockDb = MockContactDatabase();
    realDb = ContactDatabase.instance;
    ContactDatabase.instance = mockDb;
    revision = ValueNotifier<int>(0);

    when(() => mockDb.revision).thenReturn(revision);
    when(
      () => mockDb.contactsByCategoryPaged(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => [
          Contact(
            id: 1,
            name: 'Иван Иванов',
            phone: '1234567890',
            category: 'Клиент',
            status: 'Активный',
            createdAt: DateTime(2024, 1, 1),
          ),
        ]);
    when(() => mockDb.activeReminderCountByContactIds(any()))
        .thenAnswer((_) async => {});
  });

  tearDown(() {
    ContactDatabase.instance = realDb;
  });

  testWidgets('list screen shows contacts from database', (tester) async {
    await tester.pumpWidget(
      OverlaySupport.global(
        child: const MaterialApp(
          home: ContactListScreen(category: 'Клиент', title: 'Клиенты'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Иван Иванов'), findsOneWidget);
  });
}
