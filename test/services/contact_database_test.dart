import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:touchnotebookbeta_flutter/models/contact.dart';
import 'package:touchnotebookbeta_flutter/models/note.dart';
import 'package:touchnotebookbeta_flutter/models/reminder.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ContactDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('contact_db_test');
    await databaseFactoryFfi.setDatabasesPath(tempDir.path);
    db = ContactDatabase.instance;
    await db.close(); // force reopen with new path
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Contact _sampleContact({String category = 'Клиент'}) => Contact(
        name: 'Иван Иванов',
        phone: '+7 (912) 000-00-00',
        category: category,
        status: 'Активный',
        createdAt: DateTime.now(),
        tags: const [],
      );

  test('reminder CRUD operations', () async {
    final contactId = await db.insert(_sampleContact());

    final reminder1 = Reminder(
      contactId: contactId,
      dueAt: DateTime.now().add(const Duration(days: 1)),
      text: 'Позвонить',
    );
    final reminder2 = Reminder(
      contactId: contactId,
      dueAt: DateTime.now().add(const Duration(days: 2)),
      text: 'Отправить письмо',
    );

    final id1 = await db.insertReminder(reminder1);
    final id2 = await db.insertReminder(reminder2);

    final byContact = await db.remindersByContact(contactId);
    expect(byContact.length, 2);
    expect(byContact.first.id, id1);
    expect(byContact.last.id, id2);

    final paged = await db.remindersByContactPaged(contactId, limit: 1, offset: 1);
    expect(paged.length, 1);
    expect(paged.first.id, id2);

    final updatedText = 'Изменить план';
    await db.updateReminder(reminder1.copyWith(id: id1, text: updatedText));
    final afterUpdate = await db.remindersByContact(contactId);
    expect(afterUpdate.firstWhere((r) => r.id == id1).text, updatedText);

    final upcoming = await db.upcomingReminders(limit: 5);
    expect(upcoming.map((r) => r.id), containsAll({id1, id2}));

    await db.deleteReminder(id1);
    final remaining = await db.remindersByContact(contactId);
    expect(remaining.map((r) => r.id), [id2]);
  });

  test('delete and restore contact keeps notes and reminders', () async {
    final contact = _sampleContact(category: 'Партнёр');
    final contactId = await db.insert(contact);

    final note = Note(
      contactId: contactId,
      text: 'Важная заметка',
      createdAt: DateTime.now(),
    );
    await db.insertNote(note);

    final reminder = Reminder(
      contactId: contactId,
      dueAt: DateTime.now().add(const Duration(hours: 5)),
      text: 'Связаться',
    );
    await db.insertReminder(reminder);

    final snapshot = await db.deleteContactWithSnapshot(contactId);
    expect(snapshot.notes.length, 1);
    expect(snapshot.reminders.length, 1);

    // ensure contact removed
    final countAfterDelete = await db.countByCategory('Партнёр');
    expect(countAfterDelete, 0);

    final restoredId = await db.restoreContactWithRelations(
      contact.copyWith(id: null),
      snapshot,
    );

    final restoredNotes = await db.notesByContact(restoredId);
    expect(restoredNotes.length, 1);
    expect(restoredNotes.first.text, 'Важная заметка');
    expect(restoredNotes.first.contactId, restoredId);

    final restoredReminders = await db.remindersByContact(restoredId);
    expect(restoredReminders.length, 1);
    expect(restoredReminders.first.text, 'Связаться');
    expect(restoredReminders.first.contactId, restoredId);
  });
}
