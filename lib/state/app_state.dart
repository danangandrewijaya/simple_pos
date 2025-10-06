
// lib/state/app_state.dart
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repo.dart';

class AppState with ChangeNotifier {
  final repo = Repo();
  List<Product> products = [];
  List<CartItem> cart = [];

  Future<void> loadProducts([String q = '']) async {
    products = await repo.getProducts(q: q.isEmpty ? null : q);
    notifyListeners();
  }

  void addToCart(Product p) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    if (i >= 0) { cart[i].qty += 1; }
    else { cart.add(CartItem(p, 1)); }
    notifyListeners();
  }

  void changeQty(Product p, int qty) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    if (i >= 0) { cart[i].qty = qty; notifyListeners(); }
  }

  Future<void> checkout() async {
    cart.removeWhere((c) => c.qty <= 0);
    if (cart.isEmpty) return;
    await repo.createSale(cart);
    cart.clear();
    await loadProducts();
    notifyListeners();
  }
}
