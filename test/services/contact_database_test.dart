import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:touchnotebookbeta_flutter/models/contact.dart';
import 'package:touchnotebookbeta_flutter/models/note.dart';
import 'package:touchnotebookbeta_flutter/models/reminder.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';
import 'package:touchnotebookbeta_flutter/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late sqflite.DatabaseFactory originalFactory;

  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<void> _resetDatabase() async {
    await ContactDatabase.instance.close();
    final dbPath = await sqflite.getDatabasesPath();
    final path = p.join(dbPath, 'contacts.db');
    await sqflite.deleteDatabase(path);
  }

  setUp(() async {
    originalFactory = sqflite.databaseFactory;
    sqflite.databaseFactory = databaseFactoryFfi;
    EncryptionService.resetForTests(
      EncryptionService.withStorage(InMemorySecureKeyStorage()),
    );
    await _resetDatabase();
  });

  tearDown(() async {
    await _resetDatabase();
    sqflite.databaseFactory = originalFactory;
    EncryptionService.resetForTests();
  });

  test('insert and retrieve contact encrypts sensitive data', () async {
    final db = ContactDatabase.instance;
    final contact = Contact(
      name: 'Иван Иванов',
      phone: '1234567890',
      category: 'Клиент',
      status: 'Активный',
      tags: const ['VIP'],
      createdAt: DateTime(2024, 1, 1),
    );

    final id = await db.insert(contact);
    final loaded = await db.contactById(id);
    expect(loaded, isNotNull);
    expect(loaded!.name, contact.name);
    expect(loaded.phone, contact.phone);

    final rawDb = await db.database;
    final rows = await rawDb.query('contacts', where: 'id = ?', whereArgs: [id]);
    expect(rows, isNotEmpty);

    final storedName = rows.first['name'];
    expect(storedName, isA<String>());
    expect(
      (storedName as String).startsWith(EncryptionService.encryptedPrefix),
      isTrue,
    );
    expect(
      rows.first['phoneHash'],
      EncryptionService.instance.hash(contact.phone),
    );
  });

  test('notes and reminders text are encrypted at rest', () async {
    final db = ContactDatabase.instance;
    final contact = Contact(
      name: 'Test User',
      phone: '1112223333',
      category: 'Клиент',
      status: 'Активный',
      createdAt: DateTime(2024, 1, 1),
    );

    final contactId = await db.insert(contact);
    final noteId = await db.insertNote(
      Note(
        contactId: contactId,
        text: 'Чувствительная заметка',
        createdAt: DateTime(2024, 1, 2),
      ),
    );
    final reminderId = await db.insertReminder(
      Reminder(
        contactId: contactId,
        text: 'Позвонить',
        remindAt: DateTime(2024, 1, 3),
        createdAt: DateTime(2024, 1, 2),
      ),
    );

    final notes = await db.notesByContact(contactId);
    expect(notes.single.text, 'Чувствительная заметка');

    final reminders = await db.remindersByContact(contactId);
    expect(reminders.single.text, 'Позвонить');

    final rawDb = await db.database;
    final noteRows =
        await rawDb.query('notes', where: 'id = ?', whereArgs: [noteId]);
    expect(
      (noteRows.single['text'] as String)
          .startsWith(EncryptionService.encryptedPrefix),
      isTrue,
    );

    final reminderRows =
        await rawDb.query('reminders', where: 'id = ?', whereArgs: [reminderId]);
    expect(
      (reminderRows.single['text'] as String)
          .startsWith(EncryptionService.encryptedPrefix),
      isTrue,
    );
  });
}
