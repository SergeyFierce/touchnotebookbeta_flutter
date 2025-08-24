import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/contact.dart';

class ContactDatabase {
  ContactDatabase._();
  static final ContactDatabase instance = ContactDatabase._();
  Database? _db;

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
      },
    );
    return _db!;
  }

  Future<int> insert(Contact contact) async {
    final db = await database;
    return await db.insert('contacts', contact.toMap());
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

  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countByCategory(String category) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM contacts WHERE category = ?', [category]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
