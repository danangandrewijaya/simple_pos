// lib/data/repo.dart
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_db.dart';
import 'models.dart';

class Repo {
  final _db = AppDb();

  Future<List<Product>> getProducts({String? q, int? lowStockLT}) async {
    final d = await _db.db;
    final where = <String>[];
    final args = <Object?>[];
    if (q != null && q.isNotEmpty) {
      where.add('(name LIKE ? OR sku LIKE ?)');
      args..add('%$q%')..add('%$q%');
    }
    if (lowStockLT != null) {
      where.add('stock < ?');
      args.add(lowStockLT);
    }
    final res = await d.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
    return res.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> addProduct(Product p) async {
    final d = await _db.db;
    return d.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Product p) async {
    final d = await _db.db;
    return d.update('products', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    final d = await _db.db;
    return d.delete('products', where: 'id=?', whereArgs: [id]);
  }

  /// Transaksi
  Future<void> createSale(List<CartItem> items, {int? customerId}) async {
    final d = await _db.db;
    await d.transaction((txn) async {
      // Validasi stok
      for (final it in items) {
        final rows = await txn.query('products', where: 'id=?', whereArgs: [it.product.id], limit: 1);
        final current = rows.first['stock'] as int;
        if (it.qty <= 0) throw Exception('Qty untuk ${it.product.name} tidak boleh nol.');
        if (current < it.qty) {
          throw Exception('Stok ${it.product.name} kurang (tersisa $current, diminta ${it.qty}).');
        }
      }

      final total = items.fold<int>(0, (a, it) => a + it.qty * it.product.price);
      final saleId = await txn.insert('sales', {
        'created_at': DateTime.now().toIso8601String(),
        'total': total,
        'customer_id': customerId,
      });

      for (final it in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': it.product.id,
          'qty': it.qty,
          'price': it.product.price,
        });
        final updated = await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [it.qty, it.product.id],
        );
        if (updated != 1) throw Exception('Gagal mengurangi stok ${it.product.name}.');
      }
    });
  }

  // (buyers helpers removed — use customers instead)

  // Customers table helpers (id primary key, code unique)
  Future<int> addOrUpdateCustomer(String code, String name) async {
    final d = await _db.db;
    final rows = await d.query('customers', where: 'code=?', whereArgs: [code], limit: 1);
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      await d.update('customers', {'code': code, 'name': name}, where: 'id=?', whereArgs: [id]);
      return id;
    }
    return await d.insert('customers', {'code': code, 'name': name});
  }

  Future<Map<String, dynamic>?> getCustomerByCode(String code) async {
    final d = await _db.db;
    final rows = await d.query('customers', where: 'code=?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final d = await _db.db;
    final rows = await d.query('customers', where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final d = await _db.db;
    return d.query('customers', orderBy: 'name');
  }

  Future<int> deleteCustomerById(int id) async {
    final d = await _db.db;
    return d.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  /// Import customers from CSV (expects header with 'code' and 'name' or rows with code,name)
  Future<int> importCustomersCsv(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) throw Exception('File tidak ditemukan: $filePath');
    final content = await f.readAsString();
    final rows = const CsvToListConverter().convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;
    final header = rows.first.map((e)=>e.toString().trim().toLowerCase()).toList();
    final hasHeader = header.contains('code') && header.contains('name');
    final data = hasHeader ? rows.skip(1) : rows;
    int count = 0;
    final d = await _db.db;
    final batch = d.batch();
    for (final r in data) {
      final code = r.isNotEmpty ? r[0].toString().trim() : '';
      final name = r.length>1 ? r[1].toString().trim() : '';
      if (code.isEmpty) continue;
      // If customer with same code exists, update its name; otherwise insert new customer.
      final existing = await d.query('customers', where: 'code=?', whereArgs: [code], limit: 1);
      if (existing.isNotEmpty) {
        batch.update('customers', {'name': name}, where: 'code=?', whereArgs: [code]);
      } else {
        batch.insert('customers', {'code': code, 'name': name});
      }
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  Future<List<Map<String, dynamic>>> getSalesSummaryByDay() async {
    final d = await _db.db;
    return d.rawQuery('''
      SELECT substr(created_at,1,10) AS day, SUM(total) AS total
      FROM sales GROUP BY day ORDER BY day DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSalesByDay(String day) async {
    final d = await _db.db;
    // Join customers by id; sales.customer_id is nullable
    return d.rawQuery('''
      SELECT s.id, s.created_at, s.total,
             c.name AS customer_name,
             c.code AS customer_code,
             s.customer_id
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE substr(s.created_at,1,10)=?
      ORDER BY s.created_at DESC
    ''', [day]);
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final d = await _db.db;
    return d.rawQuery('''
      SELECT si.qty, si.price, p.name, p.id as product_id
      FROM sale_items si JOIN products p ON p.id = si.product_id
      WHERE si.sale_id=?
    ''', [saleId]);
  }

  Future<void> updateSaleCustomer(int saleId, {int? customerId}) async {
    final d = await _db.db;
    final values = <String, Object?>{};
    values['customer_id'] = customerId;
    await d.update('sales', values, where: 'id=?', whereArgs: [saleId]);
  }

  // ---------- CSV UTILS ----------
  Future<String> _docsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final p = Directory('${dir.path}/exports');
    if (!await p.exists()) await p.create(recursive: true);
    return p.path;
  }

  Future<String> exportProductsCsv([String? targetDir]) async {
    final d = await _db.db;
    final rows = await d.query('products', orderBy: 'name');
    final csv = const ListToCsvConverter().convert([
      ['id','name','sku','price','stock'],
      ...rows.map((r)=>[r['id'], r['name'], r['sku'], r['price'], r['stock']])
    ]);
    final path = targetDir ?? await _docsPath();
    final file = File('$path/products.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  Future<List<String>> exportSalesCsv([String? targetDir]) async {
    final d = await _db.db;
    final sales = await d.rawQuery('''
      SELECT s.id, s.created_at, s.total, c.name AS customer_name, c.code AS customer_code, s.customer_id
      FROM sales s LEFT JOIN customers c ON s.customer_id = c.id
      ORDER BY s.created_at DESC
    ''');
    final items = await d.rawQuery('''
      SELECT si.sale_id, si.product_id, p.name, si.qty, si.price
      FROM sale_items si JOIN products p ON p.id = si.product_id
      ORDER BY si.sale_id DESC
    ''');

    final csvSales = const ListToCsvConverter().convert([
      ['id','created_at','total','customer_id','customer_code','customer_name'],
      ...sales.map((s)=>[s['id'], s['created_at'], s['total'], s['customer_id'], s['customer_code'], s['customer_name']])
    ]);

    final csvItems = const ListToCsvConverter().convert([
      ['sale_id','product_id','product_name','qty','price'],
      ...items.map((it)=>[it['sale_id'], it['product_id'], it['name'], it['qty'], it['price']])
    ]);

  final path = targetDir ?? await _docsPath();
  final f1 = File('$path/sales.csv');
    await f1.writeAsString(csvSales);

  final f2 = File('$path/sale_items.csv');
    await f2.writeAsString(csvItems);

    return [f1.path, f2.path];
  }

  /// Import produk dari CSV
  Future<int> importProductsCsv(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) throw Exception('File tidak ditemukan: $filePath');
    final content = await f.readAsString();
    final rows = const CsvToListConverter().convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) return 0;
    final header = rows.first.map((e)=>e.toString().trim().toLowerCase()).toList();
    final hasHeader = header.contains('name') || header.contains('sku');
    final data = hasHeader ? rows.skip(1) : rows;
    int count = 0;
    final d = await _db.db;
    final batch = d.batch();
    for (final r in data) {
      String? name, sku; int price = 0, stock = 0; int? id;
      if (hasHeader) {
        final map = <String,String>{};
        for (int i=0;i<header.length && i<r.length;i++) { map[header[i]] = r[i].toString(); }
        name = map['name']; sku = map['sku'];
        price = int.tryParse(map['price'] ?? '0') ?? 0;
        stock = int.tryParse(map['stock'] ?? '0') ?? 0;
        id = int.tryParse(map['id'] ?? '');
      } else {
        name = r.isNotEmpty ? r[0].toString() : null;
        sku = r.length>1 ? r[1].toString() : null;
        price = r.length>2 ? int.tryParse(r[2].toString()) ?? 0 : 0;
        stock = r.length>3 ? int.tryParse(r[3].toString()) ?? 0 : 0;
      }
      if (name==null || name.isEmpty) continue;
      final values = {'id': id, 'name': name, 'sku': sku, 'price': price, 'stock': stock};
      batch.insert('products', values, conflictAlgorithm: ConflictAlgorithm.replace);
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }
}
