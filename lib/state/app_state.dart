
// lib/state/app_state.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repo.dart';

const String appName = 'Tukonin';

class AppState with ChangeNotifier {

  final repo = Repo();
  List<Product> products = [];
  List<CartItem> cart = [];
  List<CartItem>? cartBackup;
  bool lowStockOnly = false;
  int lowStockThreshold = 5;
  String query = '';
  String appTitle = appName;
  // Printer selection (persisted via SharedPreferences from PrinterService)
  String? selectedPrinterName;
  String? selectedPrinterAddress;

  static const _prefTitleKey = 'app_title';

  /// Load persisted settings (title). Call early in app startup.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    appTitle = prefs.getString(_prefTitleKey) ?? appTitle;
    notifyListeners();
  }

  // Update selected printer and notify listeners
  void setSelectedPrinter(String? name, String? address) {
    selectedPrinterName = name;
    selectedPrinterAddress = address;
    notifyListeners();
  }

  static const int maxTitleLength = 30;
  Future<void> saveTitle(String title) async {
    // Batasi jumlah karakter judul aplikasi
    if (title.length > maxTitleLength) {
      title = title.substring(0, maxTitleLength);
    }
    appTitle = title;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTitleKey, title);
    notifyListeners();
  }

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

  Future<void> checkout({int? customerId, String? customerCode, String? customerName}) async {
  cart.removeWhere((c) => c.qty <= 0);
  if (cart.isEmpty) return;
  cartBackup = cart.map((c) => CartItem(c.product, c.qty)).toList();
    // If customerCode provided and customerName non-empty, store/update customer
    if (customerCode != null && customerCode.isNotEmpty && customerName != null && customerName.isNotEmpty) {
      // ensure customer exists and get id
      final id = await repo.addOrUpdateCustomer(customerCode, customerName);
      customerId ??= id;
    }
    await repo.createSale(cart, customerId: customerId);
    cart.clear();
    await loadProducts(query);
    notifyListeners();
  }
}
