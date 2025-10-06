
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'data/models.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => AppState()..loadProducts(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Simple POS', theme: ThemeData(useMaterial3: true), home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const ProductsPage(), const CartPage(), const SummaryPage()];
    return Scaffold(
      appBar: AppBar(title: const Text('Simple POS')),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Produk'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Keranjang'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Riwayat'),
        ],
        onDestinationSelected: (i) => setState(() => idx = i),
      ),
    );
  }
}

class ProductsPage extends StatefulWidget { const ProductsPage({super.key}); @override State<ProductsPage> createState()=>_ProductsPageState(); }
class _ProductsPageState extends State<ProductsPage> {
  final c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          controller: c, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Cari produk...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (v)=>s.loadProducts(v),
        )),
        Expanded(child: ListView.builder(
          itemCount: s.products.length,
          itemBuilder: (_, i) {
            final p = s.products[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text('SKU: ${p.sku ?? '-'} • Stok: ${p.stock}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text('Rp ${p.price}'), const SizedBox(height: 4), const Icon(Icons.add_circle)],
              ),
              onTap: ()=>s.addToCart(p),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: ()=>showDialog(context: context, builder: (_)=>const AddProductDialog()),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Produk'),
          ),
        )
      ],
    );
  }
}

class AddProductDialog extends StatefulWidget { const AddProductDialog({super.key}); @override State<AddProductDialog> createState()=>_AddProductDialogState(); }
class _AddProductDialogState extends State<AddProductDialog> {
  final nameC=TextEditingController(), skuC=TextEditingController(), priceC=TextEditingController(), stockC=TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Produk Baru'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
        TextField(controller: skuC, decoration: const InputDecoration(labelText: 'SKU (opsional)')),
        TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Harga'), keyboardType: TextInputType.number),
        TextField(controller: stockC, decoration: const InputDecoration(labelText: 'Stok Awal'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () async {
          final s = context.read<AppState>();
          await s.repo.addProduct(Product(
            name: nameC.text, sku: skuC.text.isEmpty? null: skuC.text,
            price: int.tryParse(priceC.text) ?? 0, stock: int.tryParse(stockC.text) ?? 0,
          ));
          await s.loadProducts();
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('Simpan')),
      ],
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final total = s.cart.fold<int>(0, (a, it) => a + it.qty * it.product.price);
    return Column(
      children: [
        Expanded(child: ListView.builder(
          itemCount: s.cart.length,
          itemBuilder: (_, i) {
            final it = s.cart[i];
            return ListTile(
              title: Text(it.product.name),
              subtitle: Text('Harga: Rp ${it.product.price}'),
              trailing: SizedBox(
                width: 120,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.remove), onPressed: (){
                    final q = (it.qty - 1).clamp(0, 999);
                    s.changeQty(it.product, q);
                  }),
                  Text('${it.qty}'),
                  IconButton(icon: const Icon(Icons.add), onPressed: (){
                    s.changeQty(it.product, it.qty + 1);
                  }),
                ]),
              ),
            );
          },
        )),
        ListTile(title: const Text('Total'), trailing: Text('Rp $total')),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: s.cart.isEmpty ? null : () async { await s.checkout(); },
            icon: const Icon(Icons.check),
            label: const Text('Checkout'),
          ),
        )
      ],
    );
  }
}

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return FutureBuilder<List<Map<String,dynamic>>>(
      future: s.repo.getSalesSummaryByDay(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            return ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(r['day']),
              trailing: Text('Rp ${r['total']}'),
            );
          },
        );
      },
    );
  }
}
