// lib/data/models.dart
class Product {
  final int? id;
  final String name;
  final String? sku;
  final int price;
  final int stock;
  Product({this.id, required this.name, this.sku, required this.price, required this.stock});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'sku': sku, 'price': price, 'stock': stock};
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'], name: m['name'], sku: m['sku'], price: m['price'], stock: m['stock']);
}

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
}
