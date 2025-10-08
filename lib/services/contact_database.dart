import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/note.dart';
import '../models/reminder.dart';
import '../models/reminder_with_contact_info.dart';
import 'encryption_service.dart';

class ContactDatabase {
  ContactDatabase._();
  // Made non-final to allow tests to replace with a mock implementation
  static ContactDatabase instance = ContactDatabase._();
  Database? _db;

  // Ревизия для подписки экранов на изменения
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  void _bumpRevision() => revision.value++;

  static const Set<String> _contactEncryptedFields = <String>{
    'name',
    'profession',
    'city',
    'email',
    'social',
    'tags',
    'comment',
  };

  Map<String, Object?> _encryptContactData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final phone = map['phone'];
    if (phone is String && phone.isNotEmpty) {
      final plainPhone = encryption.ensureDecrypted(phone);
      map['phone'] = encryption.ensureEncrypted(plainPhone);
      map['phoneHash'] = encryption.hash(plainPhone);
    }
    for (final field in _contactEncryptedFields) {
      final value = map[field];
      if (value is String && value.isNotEmpty) {
        map[field] = encryption.ensureEncrypted(value);
      }
    }
    return map;
  }

  Map<String, Object?> _decryptContactData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final phone = map['phone'];
    if (phone is String && phone.isNotEmpty) {
      map['phone'] = encryption.ensureDecrypted(phone);
    }
    for (final field in _contactEncryptedFields) {
      final value = map[field];
      if (value is String && value.isNotEmpty) {
        map[field] = encryption.ensureDecrypted(value);
      }
    }
    map.remove('phoneHash');
    return map;
  }

  Map<String, Object?> _encryptNoteData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final text = map['text'];
    if (text is String && text.isNotEmpty) {
      map['text'] = encryption.ensureEncrypted(text);
    }
    return map;
  }

  Map<String, Object?> _decryptNoteData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final text = map['text'];
    if (text is String && text.isNotEmpty) {
      map['text'] = encryption.ensureDecrypted(text);
    }
    return map;
  }

  Map<String, Object?> _encryptReminderData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final text = map['text'];
    if (text is String && text.isNotEmpty) {
      map['text'] = encryption.ensureEncrypted(text);
    }
    return map;
  }

  Map<String, Object?> _decryptReminderData(
    Map<String, Object?> source,
    EncryptionService encryption,
  ) {
    final map = Map<String, Object?>.from(source);
    final text = map['text'];
    if (text is String && text.isNotEmpty) {
      map['text'] = encryption.ensureDecrypted(text);
    }
    return map;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'contacts.db');

    _db = await openDatabase(
      path,
      // ВАЖНО: поднимаем версию до 5, чтобы сработала миграция с шифрованием и phoneHash
      version: 5,

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
            phoneHash TEXT NOT NULL,
            email TEXT,
            social TEXT,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            tags TEXT,
            comment TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');

        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_contacts_phoneHash ON contacts(phoneHash)');

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
            remindAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER,
            FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_contactId_remindAt ON reminders(contactId, remindAt)');
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
              remindAt INTEGER NOT NULL,
              createdAt INTEGER NOT NULL,
              completedAt INTEGER,
              FOREIGN KEY(contactId) REFERENCES contacts(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_contactId_remindAt ON reminders(contactId, remindAt)');
        }

        if (oldV < 4) {
          final columns = await db.rawQuery('PRAGMA table_info(reminders)');
          final hasCompletedAt = columns.any((column) {
            final name = column['name'];
            if (name is String) return name == 'completedAt';
            return false;
          });
          if (!hasCompletedAt) {
            await db
                .execute('ALTER TABLE reminders ADD COLUMN completedAt INTEGER');
          }
        }

        if (oldV < 5) {
          final encryption = EncryptionService.instance;
          await encryption.ensureInitialized();

          final contactColumns = await db.rawQuery('PRAGMA table_info(contacts)');
          final hasPhoneHash = contactColumns.any((column) {
            final name = column['name'];
            if (name is String) return name == 'phoneHash';
            return false;
          });
          if (!hasPhoneHash) {
            await db.execute('ALTER TABLE contacts ADD COLUMN phoneHash TEXT');
          }
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_contacts_phoneHash ON contacts(phoneHash)');

          final contactRows = await db.query('contacts');
          for (final row in contactRows) {
            final id = row['id'];
            if (id is! int) continue;
            final updated = _encryptContactData(row, encryption)
              ..remove('id');
            await db.update(
              'contacts',
              updated,
              where: 'id = ?',
              whereArgs: [id],
            );
          }

          final noteRows = await db.query('notes');
          for (final row in noteRows) {
            final id = row['id'];
            if (id is! int) continue;
            final text = row['text'];
            if (text is String && !encryption.isEncrypted(text)) {
              await db.update(
                'notes',
                {'text': encryption.ensureEncrypted(text)},
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }

          final reminderRows = await db.query('reminders');
          for (final row in reminderRows) {
            final id = row['id'];
            if (id is! int) continue;
            final text = row['text'];
            if (text is String && !encryption.isEncrypted(text)) {
              await db.update(
                'reminders',
                {'text': encryption.ensureEncrypted(text)},
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }
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
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = _mapForInsert(contact.toMap());
    final encrypted = _encryptContactData(map, encryption);
    final id = await db.insert('contacts', encrypted);
    _bumpRevision();
    return id;
  }

  Future<Contact?> contactByPhone(String phone, {int? excludeId}) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final hash = encryption.hash(phone);
    final args = excludeId != null ? [hash, excludeId] : [hash];
    final where =
        excludeId != null ? 'phoneHash = ? AND id != ?' : 'phoneHash = ?';
    final maps = await db.query(
      'contacts',
      where: where,
      whereArgs: args,
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final decrypted = _decryptContactData(maps.first, encryption);
    return Contact.fromMap(decrypted);
  }

  Future<Contact?> contactById(int id) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final maps = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final decrypted = _decryptContactData(maps.first, encryption);
    return Contact.fromMap(decrypted);
  }

  Future<List<Contact>> contactsByCategory(String category) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final maps = await db.rawQuery(
      '''
      SELECT c.*,
             COALESCE(SUM(CASE
               WHEN r.completedAt IS NULL AND r.remindAt >= ? THEN 1
               ELSE 0
             END), 0) AS activeReminderCount
        FROM contacts c
        LEFT JOIN reminders r ON r.contactId = c.id
       WHERE c.category = ?
       GROUP BY c.id
      ORDER BY c.createdAt DESC
      '''.trim(),
      [now, category],
    );
    return maps
        .map((map) => Contact.fromMap(_decryptContactData(map, encryption)))
        .toList();
  }

  Future<List<Contact>> contactsByCategoryPaged(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final maps = await db.rawQuery(
      '''
      SELECT c.*,
             COALESCE(SUM(CASE
               WHEN r.completedAt IS NULL AND r.remindAt >= ? THEN 1
               ELSE 0
             END), 0) AS activeReminderCount
        FROM contacts c
        LEFT JOIN reminders r ON r.contactId = c.id
       WHERE c.category = ?
       GROUP BY c.id
       ORDER BY c.createdAt DESC
      LIMIT ? OFFSET ?
      '''.trim(),
      [now, category, limit, offset],
    );
    return maps
        .map((map) => Contact.fromMap(_decryptContactData(map, encryption)))
        .toList();
  }

  Future<int> update(Contact contact) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = Map<String, Object?>.from(contact.toMap())
      ..remove('id');
    final encrypted = _encryptContactData(map, encryption);
    final rows = await db.update(
      'contacts',
      encrypted,
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

  Future<int> activeReminderCountByCategory(String category) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(r.id) as c
        FROM reminders r
        JOIN contacts c ON c.id = r.contactId
       WHERE c.category = ?
         AND r.completedAt IS NULL
         AND r.remindAt >= ?
      '''.trim(),
      [category, now],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<int, int>> activeReminderCountByContactIds(
    List<int> contactIds,
  ) async {
    if (contactIds.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(contactIds.length, '?').join(',');
    final now = DateTime.now().millisecondsSinceEpoch;
    final args = <Object?>[now, ...contactIds];
    final rows = await db.rawQuery(
      '''
      SELECT contactId AS contactId,
             SUM(CASE
               WHEN completedAt IS NULL AND remindAt >= ? THEN 1
               ELSE 0
             END) AS activeReminderCount
        FROM reminders
       WHERE contactId IN ($placeholders)
       GROUP BY contactId
      '''.trim(),
      args,
    );
    final counts = <int, int>{};
    for (final row in rows) {
      final idValue = row['contactId'];
      final countValue = row['activeReminderCount'];
      if (idValue == null) continue;
      final id = idValue is int
          ? idValue
          : idValue is num
              ? idValue.toInt()
              : null;
      if (id == null) continue;
      final count = countValue is int
          ? countValue
          : countValue is num
              ? countValue.toInt()
              : 0;
      counts[id] = count;
    }
    return counts;
  }

  Future<int> activeReminderCount() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM reminders WHERE completedAt IS NULL AND remindAt >= ?',
      [now],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ================= Notes =================

  Future<int> insertNote(Note note) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = _mapForInsert(note.toMap());
    final encrypted = _encryptNoteData(map, encryption);
    final id = await db.insert('notes', encrypted);
    _bumpRevision();
    return id;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = Map<String, Object?>.from(note.toMap())..remove('id');
    final encrypted = _encryptNoteData(map, encryption);
    final rows = await db.update(
      'notes',
      encrypted,
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
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    return maps
        .map((map) => Note.fromMap(_decryptNoteData(map, encryption)))
        .toList();
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
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    return maps
        .map((map) => Note.fromMap(_decryptNoteData(map, encryption)))
        .toList();
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
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    return maps
        .map((map) => Note.fromMap(_decryptNoteData(map, encryption)))
        .toList();
  }

  // ================= Reminders =================

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = _mapForInsert(reminder.toMap());
    final encrypted = _encryptReminderData(map, encryption);
    final id = await db.insert('reminders', encrypted);
    _bumpRevision();
    return id;
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = Map<String, Object?>.from(reminder.toMap())..remove('id');
    final encrypted = _encryptReminderData(map, encryption);
    final rows = await db.update(
      'reminders',
      encrypted,
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    _bumpRevision();
    return rows;
  }

  Future<Reminder?> reminderById(int id) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final decrypted = _decryptReminderData(maps.first, encryption);
    return Reminder.fromMap(decrypted);
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    final rows = await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    _bumpRevision();
    return rows;
  }

  Future<int> deleteCompletedRemindersForContact(int contactId) async {
    final db = await database;
    final rows = await db.delete(
      'reminders',
      where: 'contactId = ? AND completedAt IS NOT NULL',
      whereArgs: [contactId],
    );
    if (rows > 0) {
      _bumpRevision();
    }
    return rows;
  }

  Future<List<Reminder>> completeDueRemindersForContact(int contactId) async {
    final db = await database;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final dueMaps = await db.query(
      'reminders',
      where: 'contactId = ? AND completedAt IS NULL AND remindAt <= ?',
      whereArgs: [contactId, nowEpoch],
    );

    if (dueMaps.isEmpty) return const [];

    final dueReminders = dueMaps
        .map((map) => Reminder.fromMap(_decryptReminderData(map, encryption)))
        .toList();
    final updatedReminders = <Reminder>[];
    final batch = db.batch();
    final completionMoment = DateTime.now();

    for (final reminder in dueReminders) {
      final updated = reminder.copyWith(completedAt: completionMoment);
      updatedReminders.add(updated);
      batch.update(
        'reminders',
        _encryptReminderData(
          Map<String, Object?>.from(updated.toMap())..remove('id'),
          encryption,
        ),
        where: 'id = ?',
        whereArgs: [reminder.id],
      );
    }

    await batch.commit(noResult: true);
    _bumpRevision();
    return updatedReminders;
  }

  Future<List<Reminder>> remindersByContact(
    int contactId, {
    bool onlyActive = false,
    bool onlyCompleted = false,
  }) async {
    assert(!(onlyActive && onlyCompleted),
        'Нельзя одновременно запрашивать только активные и только завершённые напоминания');
    final db = await database;
    final where = StringBuffer('contactId = ?');
    final whereArgs = <Object?>[contactId];
    var orderBy = 'remindAt ASC';

    if (onlyActive) {
      final now = DateTime.now().millisecondsSinceEpoch;
      where
        ..write(' AND completedAt IS NULL')
        ..write(' AND remindAt >= ?');
      whereArgs.add(now);
      orderBy = 'remindAt ASC';
    } else if (onlyCompleted) {
      where.write(' AND completedAt IS NOT NULL');
      orderBy = 'completedAt DESC';
    }

    final maps = await db.query(
      'reminders',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    return maps
        .map((map) => Reminder.fromMap(_decryptReminderData(map, encryption)))
        .toList();
  }

  Future<List<ReminderWithContactInfo>> remindersWithContactInfo() async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final rows = await db.rawQuery('''
      SELECT r.id AS reminder_id,
             r.contactId AS reminder_contactId,
             r.text AS reminder_text,
             r.remindAt AS reminder_remindAt,
             r.createdAt AS reminder_createdAt,
             r.completedAt AS reminder_completedAt,
             c.name AS contact_name,
             c.category AS contact_category
        FROM reminders r
        JOIN contacts c ON c.id = r.contactId
       ORDER BY r.remindAt ASC, r.id ASC
    ''');

    return rows.map((row) {
      final reminderText = row['reminder_text'];
      final decryptedText = reminderText is String
          ? encryption.ensureDecrypted(reminderText)
          : reminderText as String?;
      final reminder = Reminder(
        id: row['reminder_id'] as int?,
        contactId: row['reminder_contactId'] as int,
        text: decryptedText ?? '',
        remindAt:
            DateTime.fromMillisecondsSinceEpoch(row['reminder_remindAt'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['reminder_createdAt'] as int,
        ),
        completedAt: row['reminder_completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row['reminder_completedAt'] as int,
              )
            : null,
      );

      final rawName = row['contact_name'];
      final contactName = rawName is String
          ? encryption.ensureDecrypted(rawName)
          : rawName as String? ?? '';
      return ReminderWithContactInfo(
        reminder: reminder,
        contactName: contactName,
        contactCategory: row['contact_category'] as String,
      );
    }).toList();
  }

  // ================= Helpers для Undo =================

  /// Удаляет контакт (каскадно удаляются заметки/напоминания) и возвращает их снапшоты.
  /// В UI можно сохранить возвращённые списки для последующего Undo.
  ///
  /// Операция обёрнута в транзакцию, чтобы снимок и удаление были атомарными.
  Future<({List<Note> notes, List<Reminder> reminders})> deleteContactWithSnapshot(
      int contactId) async {
    final db = await database;
    final notes = <Note>[];
    final reminders = <Reminder>[];
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();

    await db.transaction((txn) async {
      final noteMaps = await txn.query(
        'notes',
        where: 'contactId = ?',
        whereArgs: [contactId],
        orderBy: 'createdAt DESC',
      );
      notes.addAll(noteMaps
          .map((map) => Note.fromMap(_decryptNoteData(map, encryption))));

      final reminderMaps = await txn.query(
        'reminders',
        where: 'contactId = ?',
        whereArgs: [contactId],
        orderBy: 'remindAt ASC',
      );
      reminders.addAll(reminderMaps.map(
          (map) => Reminder.fromMap(_decryptReminderData(map, encryption))));

      // Удаляем контакт — FK каскадно удалит связанные заметки и напоминания
      await txn.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
    });

    _bumpRevision();
    return (notes: notes, reminders: reminders);
  }

  /// Восстанавливает контакт (получает НОВЫЙ id) и возвращает его.
  Future<int> restoreContact(Contact contact) async {
    final db = await database;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();
    final map = _mapForInsert(contact.toMap());
    final encrypted = _encryptContactData(map, encryption);
    final newId = await db.insert('contacts', encrypted);
    _bumpRevision();
    return newId;
  }

  /// Восстанавливает контакт и ВСЕ его заметки/напоминания за одну транзакцию.
  /// Возвращает новый id контакта.
  Future<int> restoreContactWithNotes(
    Contact contact,
    List<Note> notes, [
    List<Reminder> reminders = const [],
  ]) async {
    final db = await database;
    int newContactId = 0;
    final encryption = EncryptionService.instance;
    await encryption.ensureInitialized();

    await db.transaction((txn) async {
      // Вставляем контакт
      final contactMap = _encryptContactData(
        _mapForInsert(contact.toMap()),
        encryption,
      );
      newContactId = await txn.insert('contacts', contactMap);

      // Вставляем его заметки с новым contactId
      for (final n in notes) {
        final noteMap = _encryptNoteData(
          _mapForInsert(
            n.copyWith(contactId: newContactId, id: null).toMap(),
          ),
          encryption,
        );
        await txn.insert('notes', noteMap);
      }

      // Вставляем напоминания с новым contactId
      for (final r in reminders) {
        final reminderMap = _encryptReminderData(
          _mapForInsert(
            r.copyWith(contactId: newContactId, id: null).toMap(),
          ),
          encryption,
        );
        await txn.insert('reminders', reminderMap);
      }
    });

    _bumpRevision();
    return newContactId;
  }
}
