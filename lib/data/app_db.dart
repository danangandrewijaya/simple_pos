// lib/data/app_db.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  static final AppDb _i = AppDb._();
  AppDb._();
  factory AppDb() => _i;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final p = join(await getDatabasesPath(), 'sales_app.db');
    _db = await openDatabase(
      p,
      version: 5,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sku TEXT UNIQUE,
            price INTEGER NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await d.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            total INTEGER NOT NULL,
            customer_id INTEGER,
            FOREIGN KEY(customer_id) REFERENCES customers(id)
          );
        ''');
        await d.execute('''
          CREATE TABLE sale_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            price INTEGER NOT NULL,
            FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id)
          );
        ''');
        await d.execute('''
          CREATE TABLE buyers(
            code TEXT PRIMARY KEY,
            name TEXT
          );
        ''');
        await d.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT UNIQUE,
            name TEXT
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Destructive reset: drop existing tables and recreate current schema.
        // This will erase previous data as requested.
        await db.execute('DROP TABLE IF EXISTS sale_items');
        await db.execute('DROP TABLE IF EXISTS sales');
        await db.execute('DROP TABLE IF EXISTS products');
  // drop buyers table if present (we now use customers)
  await db.execute('DROP TABLE IF EXISTS buyers');
        await db.execute('DROP TABLE IF EXISTS customers');

        // Recreate tables (current schema)
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sku TEXT UNIQUE,
            price INTEGER NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            total INTEGER NOT NULL,
            customer_id INTEGER,
            FOREIGN KEY(customer_id) REFERENCES customers(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE sale_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            price INTEGER NOT NULL,
            FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT UNIQUE,
            name TEXT
          );
        ''');
      },
    );
    return _db!;
  }
}
