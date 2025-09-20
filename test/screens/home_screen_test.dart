import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:touchnotebookbeta_flutter/screens/home_screen.dart';
import 'package:touchnotebookbeta_flutter/screens/add_contact_screen.dart';
import 'package:touchnotebookbeta_flutter/screens/contact_list_screen.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';
import 'package:touchnotebookbeta_flutter/models/contact.dart';

class MockContactDatabase extends Mock implements ContactDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockContactDatabase mockDb;
  late ValueNotifier<int> revision;
  late Map<String, int> counts;
  late ContactDatabase realDb;

  setUp(() {
    mockDb = MockContactDatabase();
    revision = ValueNotifier<int>(0);
    counts = {
      'Партнёр': 1,
      'Клиент': 2,
      'Потенциальный': 5,
    };
    realDb = ContactDatabase.instance;
    ContactDatabase.instance = mockDb;

    when(() => mockDb.revision).thenReturn(revision);
    when(() => mockDb.countByCategory(any())).thenAnswer(
          (invocation) async => counts[invocation.positionalArguments.first] ?? 0,
    );
    when(() => mockDb.contactsByCategoryPaged(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    )).thenAnswer((_) async => <Contact>[]);
  });

  tearDown(() {
    ContactDatabase.instance = realDb;
  });

  testWidgets('category cards display correct counts and plural forms', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));
    await tester.pump(); // start future
    await tester.pump(); // finish future

    expect(find.text('1 партнёр'), findsOneWidget);
    expect(find.text('2 клиента'), findsOneWidget);
    expect(find.text('5 потенциальных'), findsOneWidget);
  });

  testWidgets('tapping category navigates to ContactListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Партнёры'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactListScreen), findsOneWidget);
  });

  testWidgets('tapping FAB navigates to AddContactScreen and refreshes counts on return', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AddContactScreen), findsOneWidget);

    counts['Партнёр'] = 2;
    counts['Клиент'] = 3;
    counts['Потенциальный'] = 6;
    revision.value++;

    Navigator.of(tester.element(find.byType(AddContactScreen))).pop(true);
    await tester.pumpAndSettle();

    expect(find.text('2 партнёра'), findsOneWidget);
    expect(find.text('3 клиента'), findsOneWidget);
    expect(find.text('6 потенциальных'), findsOneWidget);
  });


  testWidgets('manual refresh reloads counts without revision change', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));
    await tester.pump();
    await tester.pump();

    counts['Партнёр'] = 4;
    counts['Клиент'] = 5;
    counts['Потенциальный'] = 6;

    await tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump();

    expect(find.text('4 партнёра'), findsOneWidget);
    expect(find.text('5 клиентов'), findsOneWidget);
    expect(find.text('6 потенциальных'), findsOneWidget);
  });
}