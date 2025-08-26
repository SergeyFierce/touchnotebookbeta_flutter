import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/note.dart';

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
      // ВАЖНО: поднимаем версию до 2, чтобы сработала миграция с FK + CASCADE
      version: 2,

      // Включаем поддержку внешних ключей (иначе SQLite их игнорирует)
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

        // ВАЖНО: тут была пропущена запятая перед FOREIGN KEY — добавили
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contactId INTEGER NOT NULL,
            text TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
          )
        ''');

        // Полезные индексы
        await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_category_createdAt ON contacts(category, createdAt)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_contactId_createdAt ON notes(contactId, createdAt)');
      },

      onUpgrade: (db, oldV, newV) async {
        // Переезд на схему с FK + CASCADE и зачистка сиротских заметок
        if (oldV < 2) {
          // На всякий случай включим FK в апгрейде
          await db.execute('PRAGMA foreign_keys = OFF'); // на время миграции
          // Переопределяем таблицу notes с FK + CASCADE
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

          // Переносим только валидные заметки (те, у которых есть родительский контакт)
          await db.execute('''
            INSERT INTO notes(id, contactId, text, createdAt)
            SELECT n.id, n.contactId, n.text, n.createdAt
            FROM notes_old n
            JOIN contacts c ON c.id = n.contactId
          ''');

          await db.execute('DROP TABLE notes_old');

          // Индексы могли пропасть — восстановим
          await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_category_createdAt ON contacts(category, createdAt)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_contactId_createdAt ON notes(contactId, createdAt)');

          await db.execute('PRAGMA foreign_keys = ON'); // включаем обратно
        }
      },
    );

    // Каждое открытие соединения — ещё раз страхуемся, что FK включены
    await _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  // ---- Вспомогательное: карта для insert без id ----
  Map<String, Object?> _mapForInsert(Map<String, Object?> src) {
    final m = Map<String, Object?>.from(src);
    m.remove('id');
    return m;
  }

  // ================= Contacts =================

  Future<int> insert(Contact contact) async {
    final db = await database;
    final id = await db.insert('contacts', _mapForInsert(contact.toMap()));
    _bumpRevision();
    return id;
  }

  Future<List<Contact>> contactsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Contact.fromMap).toList();
  }

  Future<int> update(Contact contact) async {
    final db = await database;
    final rows = await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
    _bumpRevision();
    return rows;
  }

  Future<int> delete(int id) async {
    final db = await database;
    final rows = await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
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
    final db = await database;
    final id = await db.insert('notes', _mapForInsert(note.toMap()));
    _bumpRevision();
    return id;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    final rows = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    _bumpRevision();
    return rows;
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    final rows = await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    _bumpRevision();
    return rows;
  }

  Future<List<Note>> notesByContact(int contactId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
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

  /// Удаляет контакт (каскадно удаляются заметки) и возвращает снапшот заметок.
  /// В UI можно сохранить возвращённый список для последующего Undo.
  Future<List<Note>> deleteContactWithSnapshot(int contactId) async {
    final db = await database;
    // Снимок заметок до удаления
    final snapshot = await notesByContact(contactId);

    // Удаляем контакт — FK прибьёт notes
    await db.delete('contacts', where: 'id = ?', whereArgs: [contactId]);

    _bumpRevision();
    return snapshot;
  }

  /// Восстанавливает контакт (получает НОВЫЙ id) и возвращает его.
  Future<int> restoreContact(Contact contact) async {
    final db = await database;
    final newId = await db.insert('contacts', _mapForInsert(contact.toMap()));
    _bumpRevision();
    return newId;
  }

  /// Восстанавливает контакт и ВСЕ его заметки за одну транзакцию.
  /// Возвращает новый id контакта.
  Future<int> restoreContactWithNotes(Contact contact, List<Note> notes) async {
    final db = await database;
    int newContactId = 0;

    await db.transaction((txn) async {
      // Вставляем контакт
      newContactId = await txn.insert('contacts', _mapForInsert(contact.toMap()));

      // Вставляем его заметки с новым contactId
      for (final n in notes) {
        final noteMap = _mapForInsert(n.copyWith(contactId: newContactId, id: null).toMap());
        await txn.insert('notes', noteMap);
      }
    });

    _bumpRevision();
    return newContactId;
  }
}
