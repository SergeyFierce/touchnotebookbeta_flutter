import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:touchnotebookbeta_flutter/models/contact.dart';
import 'package:touchnotebookbeta_flutter/models/note.dart';
import 'package:touchnotebookbeta_flutter/services/contact_database.dart';

Future<void> _clearDb() async {
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'contacts.db');
  await deleteDatabase(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await ContactDatabase.instance.dispose();
    await _clearDb();
  });

  test('insert, update, delete contact', () async {
    final db = ContactDatabase.instance;
    final contact = Contact(
      name: 'John',
      phone: '123',
      category: 'friends',
      status: 'active',
      createdAt: DateTime.now(),
    );

    final id = await db.insert(contact);
    expect(id, greaterThan(0));

    final updated = Contact(
      id: id,
      name: 'Jane',
      phone: '123',
      category: 'friends',
      status: 'active',
      createdAt: contact.createdAt,
    );

    await db.update(updated);
    final contacts = await db.contactsByCategory('friends');
    expect(contacts.single.name, 'Jane');

    await db.delete(id);
    final remaining = await db.contactsByCategory('friends');
    expect(remaining, isEmpty);
  });

  test('insert, update, delete note', () async {
    final db = ContactDatabase.instance;
    final contactId = await db.insert(Contact(
      name: 'John',
      phone: '123',
      category: 'friends',
      status: 'active',
      createdAt: DateTime.now(),
    ));

    final note = Note(
      contactId: contactId,
      text: 'hello',
      createdAt: DateTime.now(),
    );

    final noteId = await db.insertNote(note);
    expect(noteId, greaterThan(0));

    await db.updateNote(note.copyWith(id: noteId, text: 'updated'));
    final notes = await db.notesByContact(contactId);
    expect(notes.single.text, 'updated');

    await db.deleteNote(noteId);
    final remaining = await db.notesByContact(contactId);
    expect(remaining, isEmpty);
  });

  test('migrates from v1 to v3 using in-memory db', () async {
    const memoryPath = 'file:memdb1?mode=memory&cache=shared';

    final db = await openDatabase(
      memoryPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            birthDate INTEGER,
            ageManual INTEGER,
            profession TEXT,
            city TEXT,
            phone TEXT NOT NULL,
            email TEXT,
            social TEXT,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            tags TEXT,
            comment TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contactId INTEGER NOT NULL,
            text TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
      singleInstance: false,
    );

    final contactId = await db.insert('contacts', {
      'name': 'John',
      'phone': '123',
      'category': 'friends',
      'status': 'active',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    await db.insert('notes', {
      'contactId': contactId,
      'text': 'valid',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    await db.insert('notes', {
      'contactId': 999,
      'text': 'invalid',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('ALTER TABLE notes RENAME TO notes_old');
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactId INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      INSERT INTO notes(id, contactId, text, createdAt)
      SELECT n.id, n.contactId, n.text, n.createdAt
      FROM notes_old n
      JOIN contacts c ON c.id = n.contactId
    ''');
    await db.execute('DROP TABLE notes_old');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_category_createdAt ON contacts(category, createdAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_tags ON contacts(tags)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_contactId_createdAt ON notes(contactId, createdAt)');
    await db.execute('PRAGMA foreign_keys = ON');

    final notes = await db.query('notes');
    expect(notes.length, 1);
    expect(notes.first['text'], 'valid');

    final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_contacts_name'");
    expect(indexes.isNotEmpty, true);

    await db.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
    final remaining = await db.query('notes');
    expect(remaining, isEmpty);

    await db.close();
  });
}

