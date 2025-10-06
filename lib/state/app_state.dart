// lib/state/app_state.dart
import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repo.dart';

class AppState with ChangeNotifier {
  final repo = Repo();
  List<Product> products = [];
  List<CartItem> cart = [];
  bool lowStockOnly = false;
  int lowStockThreshold = 5;
  String query = '';

  Future<void> loadProducts([String q = '']) async {
    query = q;
    // Fetch all products (optionally filtered by query), then optionally
    // remove low-stock items client-side when lowStockOnly is enabled.
    final all = await repo.getProducts(q: q.isEmpty ? null : q);
    products = lowStockOnly
        ? all.where((p) => p.stock >= lowStockThreshold).toList()
        : all;
    notifyListeners();
  }

  void toggleLowStock([bool? v]) {
    lowStockOnly = v ?? !lowStockOnly;
    loadProducts(query);
  }

  void setThreshold(int t) {
    lowStockThreshold = t;
    loadProducts(query);
  }

  /// Try to add product to cart. Returns true if added, false otherwise
  bool addToCart(Product p) {
    // Do not add product with zero stock
    if (p.stock == 0) return false;
    final i = cart.indexWhere((c) => c.product.id == p.id);
    final currentQty = i >= 0 ? cart[i].qty : 0;
    // If adding one more exceeds stock, reject
    if (currentQty + 1 > p.stock) return false;
    if (i >= 0) {
      cart[i].qty = currentQty + 1;
    } else {
      cart.add(CartItem(p, 1));
    }
    notifyListeners();
    return true;
  }

  /// Change quantity for a product in cart.
  /// Returns true if change applied, false if rejected (e.g. exceeds stock or product not in cart).
  bool changeQty(Product p, int qty) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    if (i < 0) return false; // not found
    if (qty <= 0) {
      cart.removeAt(i);
      notifyListeners();
      return true;
    }
    // Do not allow qty greater than available stock
    if (qty > p.stock) return false;
    cart[i].qty = qty;
    notifyListeners();
    return true;
  }

  Future<void> checkout({String? buyer, String? buyerCode, String? buyerName}) async {
    cart.removeWhere((c) => c.qty <= 0);
    if (cart.isEmpty) return;
    // If buyerCode provided and buyerName non-empty, store/update buyer
    if (buyerCode != null && buyerCode.isNotEmpty && buyerName != null && buyerName.isNotEmpty) {
      await repo.addOrUpdateBuyer(buyerCode, buyerName);
    }
    await repo.createSale(cart, buyer: buyer, buyerCode: buyerCode);
    cart.clear();
    await loadProducts(query);
    notifyListeners();
  }
}
