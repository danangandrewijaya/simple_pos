
// lib/data/app_db.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
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
            total INTEGER NOT NULL
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
      },
    );
    return _db!;
  }
}
