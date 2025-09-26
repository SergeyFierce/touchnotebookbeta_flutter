import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/note.dart';
import '../models/reminder.dart';
import 'reminder_notifications.dart';

class ContactDatabase {
  ContactDatabase._();
  // Made non-final to allow tests to replace with a mock implementation
  static ContactDatabase instance = ContactDatabase._();
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
      // ВАЖНО: поднимаем версию до 3, чтобы сработали миграции с FK и напоминаниями
      version: 3,

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
        await db.execute('''
          CREATE TABLE reminders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contactId INTEGER NOT NULL,
            text TEXT NOT NULL,
            scheduledAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_contactId_scheduledAt ON reminders(contactId, scheduledAt)');
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

        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS reminders(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              contactId INTEGER NOT NULL,
              text TEXT NOT NULL,
              scheduledAt INTEGER NOT NULL,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_contactId_scheduledAt ON reminders(contactId, scheduledAt)');
        }
      },
    );

    // Каждое открытие соединения — ещё раз страхуемся, что FK включены
    await _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  /// Закрывает подключение к базе. При следующем обращении [database]
  /// соединение будет открыто заново. Полезно вызывать при завершении
  /// приложения, чтобы избежать утечек ресурсов в продакшене.
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
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

  Future<List<Contact>> contactsByCategoryPaged(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
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
    await cancelRemindersForContact(id);
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

  Future<List<Note>> notesByContactPaged(
    int contactId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
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

  // ================= Reminders =================

  Future<List<Reminder>> remindersByContact(int contactId) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'scheduledAt ASC',
    );
    return maps.map(Reminder.fromMap).toList();
  }

  Future<List<Reminder>> upcomingRemindersByContact(int contactId, {int limit = 3}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'reminders',
      where: 'contactId = ? AND scheduledAt >= ?',
      whereArgs: [contactId, now - const Duration(minutes: 1).inMilliseconds],
      orderBy: 'scheduledAt ASC',
      limit: limit,
    );
    return maps.map(Reminder.fromMap).toList();
  }

  Future<int> insertReminder(Reminder reminder, {required String contactName}) async {
    final db = await database;
    final id = await db.insert('reminders', _mapForInsert(reminder.toMap()));
    final stored = reminder.copyWith(id: id);
    await ReminderNotifications.instance.scheduleReminder(stored, contactName: contactName);
    _bumpRevision();
    return id;
  }

  Future<int> updateReminder(Reminder reminder, {required String contactName}) async {
    if (reminder.id == null) return 0;
    final db = await database;
    final rows = await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    if (rows > 0) {
      await ReminderNotifications.instance.scheduleReminder(reminder, contactName: contactName);
      _bumpRevision();
    }
    return rows;
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    final rows = await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    if (rows > 0) {
      await ReminderNotifications.instance.cancelReminder(id);
      _bumpRevision();
    }
    return rows;
  }

  Future<void> cancelRemindersForContact(int contactId) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      columns: ['id'],
      where: 'contactId = ?',
      whereArgs: [contactId],
    );
    final ids = maps.map((e) => e['id']).whereType<int>();
    await ReminderNotifications.instance.cancelReminders(ids);
  }

  Future<List<ReminderScheduleInfo>> _reminderScheduleEntries({int? contactId}) async {
    final db = await database;
    final args = <Object?>[];
    final buffer = StringBuffer();
    if (contactId != null) {
      buffer.write('WHERE r.contactId = ?');
      args.add(contactId);
    } else {
      buffer.write('WHERE r.scheduledAt >= ?');
      args.add(DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch);
    }

    final rows = await db.rawQuery('''
      SELECT
        r.id as id,
        r.contactId as contactId,
        r.text as text,
        r.scheduledAt as scheduledAt,
        r.createdAt as createdAt,
        c.name as contactName
      FROM reminders r
      JOIN contacts c ON c.id = r.contactId
      ${buffer.toString()}
      ORDER BY r.scheduledAt ASC
    ''', args);

    return rows
        .map((row) => ReminderScheduleInfo(
              reminder: Reminder.fromMap(row),
              contactName: row['contactName'] as String,
            ))
        .toList();
  }

  Future<void> reschedulePendingReminders() async {
    final entries = await _reminderScheduleEntries();
    for (final entry in entries) {
      await ReminderNotifications.instance.scheduleReminder(
        entry.reminder,
        contactName: entry.contactName,
      );
    }
  }

  Future<void> rescheduleRemindersForContact(int contactId) async {
    final entries = await _reminderScheduleEntries(contactId: contactId);
    for (final entry in entries) {
      await ReminderNotifications.instance.scheduleReminder(
        entry.reminder,
        contactName: entry.contactName,
      );
    }
  }

  // ================= Helpers для Undo =================

  /// Удаляет контакт (каскадно удаляются заметки) и возвращает снапшот заметок.
  /// В UI можно сохранить возвращённый список для последующего Undo.
  ///
  /// Операция обёрнута в транзакцию, чтобы снимок и удаление были атомарными.
  Future<List<Note>> deleteContactWithSnapshot(int contactId) async {
    final db = await database;
    final snapshot = <Note>[];
    final reminderIds = <int>[];

    await db.transaction((txn) async {
      final maps = await txn.query(
        'notes',
        where: 'contactId = ?',
        whereArgs: [contactId],
        orderBy: 'createdAt DESC',
      );
      snapshot.addAll(maps.map(Note.fromMap));

      final reminders = await txn.query(
        'reminders',
        columns: ['id'],
        where: 'contactId = ?',
        whereArgs: [contactId],
      );
      reminderIds.addAll(reminders.map((e) => e['id']).whereType<int>());

      // Удаляем контакт — FK каскадно удалит связанные заметки
      await txn.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
    });

    if (reminderIds.isNotEmpty) {
      await ReminderNotifications.instance.cancelReminders(reminderIds);
    }

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
