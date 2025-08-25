import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart'; // <-- добавили
import '../models/contact.dart';
import '../models/note.dart';

class ContactDatabase {
  ContactDatabase._();
  static final ContactDatabase instance = ContactDatabase._();
  Database? _db;

  // <-- НОВОЕ: ревизия БД, на неё подпишется главный экран
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  void _bumpRevision() => revision.value++;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'contacts.db');
    _db = await openDatabase(
      path,
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
      onOpen: (db) async {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contactId INTEGER NOT NULL,
          text TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
        ''');
      },
    );
    return _db!;
  }

  Future<int> insert(Contact contact) async {
    final db = await database;
    final id = await db.insert('contacts', contact.toMap());
    _bumpRevision(); // <-- сообщаем подписчикам
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
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<int> update(Contact contact) async {
    final db = await database;
    final rows = await db.update('contacts', contact.toMap(), where: 'id = ?', whereArgs: [contact.id]);
    _bumpRevision();
    return rows;
  }

  Future<int> delete(int id) async {
    final db = await database;
    final rows = await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    _bumpRevision(); // <-- и тут тоже
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

  // ===== Notes =====

  Future<int> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    _bumpRevision();
    return id;
    }

  Future<List<Note>> notesByContact(int contactId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'contactId = ?',
      whereArgs: [contactId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
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
    return maps.map((e) => Note.fromMap(e)).toList();
  }
}
