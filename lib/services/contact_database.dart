import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/note.dart';

// Custom exception для ошибок БД
class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
}

class ContactDatabase {
  ContactDatabase._();
  static final ContactDatabase instance = ContactDatabase._();
  Database? _db;

  // Ревизия для подписки экранов на изменения
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  void _bumpRevision() => revision.value++;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'contacts.db');

    _db = await openDatabase(
      path,
      version: 3, // Bump до 3 для новых индексов в миграции

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

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
            createdAt INTEGER NOT NULL,
            FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
          )
        ''');

        // Индексы для производительности
        await _createIndexes(db);
      },

      onUpgrade: (db, oldV, newV) async {
        await db.execute('PRAGMA foreign_keys = OFF'); // На время миграции
        try {
          if (oldV < 2) {
            // Миграция на FK + CASCADE (как раньше)
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
          }

          if (oldV < 3) {
            // Добавляем новые индексы в миграции
            await _createIndexes(db);
          }
        } catch (e, st) {
          debugPrint('Migration from $oldV to $newV failed: $e');
          debugPrint(st.toString());
          rethrow;
        } finally {
          await db.execute('PRAGMA foreign_keys = ON');
        }
      },
    );

    await _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  // Helper для создания индексов (вынесли для reuse)
  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_category_createdAt ON contacts(category, createdAt)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_tags ON contacts(tags)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_contactId_createdAt ON notes(contactId, createdAt)');
  }

  // Вспомогательное: карта для insert без id
  Map<String, Object?> _mapForInsert(Map<String, Object?> src) {
    final m = Map<String, Object?>.from(src);
    m.remove('id');
    return m;
  }

  // Валидация контакта перед insert/update
  void _validateContact(Contact contact) {
    if (contact.name.isEmpty) throw DatabaseException('Name cannot be empty');
    if (contact.phone.isEmpty) throw DatabaseException('Phone cannot be empty');
    if (contact.category.isEmpty) throw DatabaseException('Category cannot be empty');
    if (contact.status.isEmpty) throw DatabaseException('Status cannot be empty');
    // Можно добавить больше валидаций, например, на формат phone
  }

  // ================= Contacts =================

  Future<int> insert(Contact contact) async {
    _validateContact(contact);
    final db = await database;
    final id = await db.insert('contacts', _mapForInsert(contact.toMap()));
    _bumpRevision();
    return id;
  }

  Future<List<Contact>> contactsByCategory(String category, {String orderBy = 'createdAt DESC'}) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: orderBy,
    );
    return maps.map(Contact.fromMap).toList();
  }

  Future<List<Contact>> contactsByCategoryPaged(
      String category, {
        int limit = 20,
        int offset = 0,
        String orderBy = 'createdAt DESC',
      }) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map(Contact.fromMap).toList();
  }

  // Новый: поиск по имени (частичный, case-insensitive)
  Future<List<Contact>> searchContactsByName(String query, {String? category, int limit = 20}) async {
    final db = await database;
    String where = 'name LIKE ?';
    List<Object?> args = ['%$query%'];
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }
    final maps = await db.query(
      'contacts',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: limit,
    );
    return maps.map(Contact.fromMap).toList();
  }

  // Новый: поиск по тегам (tags как comma-separated string, e.g. "tag1,tag2")
  Future<List<Contact>> searchByTags(String tag, {String? category, int limit = 20}) async {
    final db = await database;
    String where = 'tags LIKE ?';
    List<Object?> args = ['%,$tag,%']; // Для comma-separated, чтобы матчить целые теги
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }
    final maps = await db.query(
      'contacts',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return maps.map(Contact.fromMap).toList();
  }

  Future<int> update(Contact contact) async {
    _validateContact(contact);
    final db = await database;
    final rows = await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
    if (rows == 0) throw DatabaseException('Contact with id ${contact.id} not found');
    _bumpRevision();
    return rows;
  }

  Future<int> delete(int id) async {
    final db = await database;
    final rows = await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    if (rows == 0) throw DatabaseException('Contact with id $id not found');
    _bumpRevision();
    return rows;
  }

  Future<int> countByCategory(String category) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM contacts WHERE category = ?',
      [category],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ================= Notes =================

  Future<int> insertNote(Note note) async {
    if (note.text.isEmpty) throw DatabaseException('Note text cannot be empty');
    final db = await database;
    final id = await db.insert('notes', _mapForInsert(note.toMap()));
    _bumpRevision();
    return id;
  }

  Future<int> updateNote(Note note) async {
    if (note.text.isEmpty) throw DatabaseException('Note text cannot be empty');
    final db = await database;
    final rows = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (rows == 0) throw DatabaseException('Note with id ${note.id} not found');
    _bumpRevision();
    return rows;
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    final rows = await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    if (rows == 0) throw DatabaseException('Note with id $id not found');
    _bumpRevision();
    return rows;
  }

  Future<List<Note>> notesByContact(int contactId, {String orderBy = 'createdAt DESC'}) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: orderBy,
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<List<Note>> notesByContactPaged(
      int contactId, {
        int limit = 20,
        int offset = 0,
        String orderBy = 'createdAt DESC',
      }) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<List<Note>> lastNotesByContact(int contactId, {int limit = 3}) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return maps.map(Note.fromMap).toList();
  }

  // ================= Helpers для Undo =================

  Future<List<Note>> deleteContactWithSnapshot(int contactId) async {
    final db = await database;
    final snapshot = await notesByContact(contactId);
    final rows = await db.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
    if (rows == 0) throw DatabaseException('Contact with id $contactId not found');
    _bumpRevision();
    return snapshot;
  }

  Future<int> restoreContact(Contact contact) async {
    _validateContact(contact);
    final db = await database;
    final newId = await db.insert('contacts', _mapForInsert(contact.toMap()));
    _bumpRevision();
    return newId;
  }

  Future<int> restoreContactWithNotes(Contact contact, List<Note> notes) async {
    _validateContact(contact);
    final db = await database;
    int newContactId = 0;

    await db.transaction((txn) async {
      newContactId = await txn.insert('contacts', _mapForInsert(contact.toMap()));

      // Проверка: все notes должны быть для этого контакта
      final oldContactId = notes.isNotEmpty ? notes.first.contactId : null;
      if (notes.any((n) => n.contactId != oldContactId)) {
        throw DatabaseException('All notes must belong to the same contact');
      }

      // Batch для эффективности
      final batch = txn.batch();
      for (final n in notes) {
        final noteMap = _mapForInsert(n.copyWith(contactId: newContactId, id: null).toMap());
        batch.insert('notes', noteMap);
      }
      await batch.commit(noResult: true);
    });

    _bumpRevision();
    return newContactId;
  }

  // ================= Экспорт данных =================

  // Новый: экспорт всех данных в JSON-подобный Map для бэкапа
  Future<Map<String, dynamic>> exportToJson() async {
    final db = await database;
    final contactsMaps = await db.query('contacts', orderBy: 'id ASC');
    final notesMaps = await db.query('notes', orderBy: 'id ASC');
    return {
      'contacts': contactsMaps,
      'notes': notesMaps,
    };
  }

  // Dispose для закрытия БД (вызывать в app dispose)
  Future<void> dispose() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}