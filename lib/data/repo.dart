
// lib/data/repo.dart
import 'app_db.dart';
import 'models.dart';

class Repo {
  final _db = AppDb();

  Future<List<Product>> getProducts({String? q}) async {
    final d = await _db.db;
    final res = q == null || q.isEmpty
        ? await d.query('products', orderBy: 'name')
        : await d.query('products', where: 'name LIKE ?', whereArgs: ['%$q%'], orderBy: 'name');
    return res.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> addProduct(Product p) async {
    final d = await _db.db;
    return d.insert('products', p.toMap());
  }

  Future<int> updateProduct(Product p) async {
    final d = await _db.db;
    return d.update('products', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    final d = await _db.db;
    return d.delete('products', where: 'id=?', whereArgs: [id]);
  }

  /// Simpan transaksi + kurangi stok (atomic dengan transaction)
  Future<void> createSale(List<CartItem> items) async {
    final d = await _db.db;
    await d.transaction((txn) async {
      final total = items.fold<int>(0, (a, it) => a + it.qty * it.product.price);
      final saleId = await txn.insert('sales', {
        'created_at': DateTime.now().toIso8601String(),
        'total': total,
      });
      for (final it in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': it.product.id,
          'qty': it.qty,
          'price': it.product.price,
        });
        // Kurangi stok (cegah negatif stok)
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
          [it.qty, it.product.id, it.qty],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSalesSummaryByDay() async {
    final d = await _db.db;
    return d.rawQuery('''
      SELECT substr(created_at,1,10) AS day, SUM(total) AS total
      FROM sales GROUP BY day ORDER BY day DESC
    ''');
  }
}
