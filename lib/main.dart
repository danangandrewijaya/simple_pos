// lib/main.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'data/money.dart';
import 'state/app_state.dart';

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
      appBar: AppBar(
        title: const Text('Simple POS'),
        // actions: idx==0? const [ProductsActions()] : null, // hide
      ),
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

class ProductsActions extends StatelessWidget {
  const ProductsActions({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final thText = TextEditingController(text: s.lowStockThreshold.toString());
    return Row(children: [
      const Text('Stok < '),
      SizedBox(width: 48, child: TextField(
        controller: thText,
        keyboardType: TextInputType.number,
        onSubmitted: (v){ final n=int.tryParse(v)??5; context.read<AppState>().setThreshold(n); },
      )),
      Switch(value: s.lowStockOnly, onChanged: (v)=>context.read<AppState>().toggleLowStock(v)),
      PopupMenuButton<String>(
        onSelected: (v) async {
          final repo = context.read<AppState>().repo;
          if (v=='export_products') {
            final path = await repo.exportProductsCsv();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produk diekspor ke: $path')));
            }
          } else if (v=='export_sales') {
            final paths = await repo.exportSalesCsv();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transaksi diekspor ke: ${paths.join(', ')}')));
            }
          } else if (v=='import_products') {
            final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
            if (res!=null && res.files.isNotEmpty) {
              final filePath = res.files.single.path!;
              final n = await repo.importProductsCsv(filePath);
              await context.read<AppState>().loadProducts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impor selesai: $n produk')));
              }
            }
          }
        },
        itemBuilder: (c)=>const [
          PopupMenuItem(value:'export_products', child: Text('Ekspor CSV - Produk')),
          PopupMenuItem(value:'export_sales', child: Text('Ekspor CSV - Transaksi')),
          PopupMenuItem(value:'import_products', child: Text('Impor CSV - Produk')),
        ],
      ),
    ]);
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
                  subtitle: Text(
                    'SKU: ${p.sku ?? '-'} • Stok: ${p.stock}',
                    style: p.stock == 0 ? const TextStyle(color: Colors.red) : null,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(idr(p.price)),
                      const SizedBox(height: 4),
                      p.stock > 0
                          ? const Icon(Icons.add_circle)
                          : const Icon(Icons.block, color: Colors.red),
                    ],
                  ),
                  onTap: () {
                    final added = s.addToCart(p);
                    if (!added) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak cukup')));
                      return;
                    }
                    // find remaining stock after adding
                    final inCart = s.cart.firstWhere((c) => c.product.id == p.id, orElse: () => CartItem(p, 0));
                    final remaining = p.stock - inCart.qty;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ditambahkan — tersisa $remaining')));
                  },
                  onLongPress: () => showDialog(context: context, builder: (_) => EditProductDialog(p: p)),
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

class EditProductDialog extends StatefulWidget {
  final Product p;
  const EditProductDialog({super.key, required this.p});
  @override State<EditProductDialog> createState()=>_EditProductDialogState();
}
class _EditProductDialogState extends State<EditProductDialog> {
  late final nameC = TextEditingController(text: widget.p.name);
  late final skuC  = TextEditingController(text: widget.p.sku ?? '');
  late final priceC= TextEditingController(text: widget.p.price.toString());
  late final stockC= TextEditingController(text: widget.p.stock.toString());
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Produk'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
        TextField(controller: skuC,  decoration: const InputDecoration(labelText: 'SKU')),
        TextField(controller: priceC,decoration: const InputDecoration(labelText: 'Harga'), keyboardType: TextInputType.number),
        TextField(controller: stockC,decoration: const InputDecoration(labelText: 'Stok'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
            title: const Text('Hapus produk?'), content: Text('Hapus ${widget.p.name}?'),
            actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                      FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Hapus'))],
          )) ?? false;
          if (!ok) return;
          final s = context.read<AppState>();
          await s.repo.deleteProduct(widget.p.id!);
          await s.loadProducts();
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('Hapus')),
        FilledButton(onPressed: () async {
          final s = context.read<AppState>();
          await s.repo.updateProduct(Product(
            id: widget.p.id,
            name: nameC.text,
            sku: skuC.text.isEmpty ? null : skuC.text,
            price: int.tryParse(priceC.text) ?? widget.p.price,
            stock: int.tryParse(stockC.text) ?? widget.p.stock,
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
              subtitle: Text('Harga: ${idr(it.product.price)}'),
              trailing: SizedBox(
                width: 120,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.remove), onPressed: (){
                    final q = (it.qty - 1).clamp(0, 999);
                    s.changeQty(it.product, q);
                  }),
                  Text('${it.qty}'),
                  IconButton(icon: const Icon(Icons.add), onPressed: (){
                    final success = s.changeQty(it.product, it.qty + 1);
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak cukup')));
                    }
                  }),
                ]),
              ),
            );
          },
        )),
        ListTile(title: const Text('Total'), trailing: Text(idr(total))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: s.cart.isEmpty ? null : () async {
              final nameC = TextEditingController();
              final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                title: const Text('Simpan Transaksi'),
                content: TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Pembeli (opsional)')),
                actions: [
                  TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                  FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Simpan')),
                ],
              )) ?? false;
              if (!ok) return;
              try {
                await s.checkout(buyer: nameC.text.isEmpty ? null : nameC.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi tersimpan')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
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
              trailing: Text(idr(r['total'])),
              onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>SalesOfDayPage(day: r['day']))),
            );
          },
        );
      },
    );
  }
}

class SalesOfDayPage extends StatelessWidget {
  final String day;
  const SalesOfDayPage({super.key, required this.day});
  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().repo;
    return Scaffold(
      appBar: AppBar(title: Text('Transaksi $day')),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: repo.getSalesByDay(day),
        builder: (_, snap){
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if(rows.isEmpty) return const Center(child: Text('Tidak ada transaksi'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (_, i){
              final s = rows[i];
              final dt = DateTime.parse(s['created_at']).toLocal();
              final time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
              final buyerName = (s['buyer'] as String?) ?? '';
              return ListTile(
                title: Text(idr(s['total'])),
                subtitle: Text(time),
                trailing: buyerName.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Pembeli', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(buyerName, style: const TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
                onTap: () async {
                  final items = await repo.getSaleItems(s['id'] as int);
                  // ignore: use_build_context_synchronously
                  showDialog(context: context, builder: (_)=>AlertDialog(
                    title: const Text('Detail Transaksi'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((s['buyer'] as String?)?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(children: [const Text('Pembeli: ', style: TextStyle(fontWeight: FontWeight.bold)), Text(s['buyer'] as String)]),
                            ),
                          ...items.map((it)=>ListTile(
                            dense: true,
                            title: Text(it['name'] as String),
                            trailing: Text('${it['qty']} x ${idr(it['price'])}'),
                          )).toList(),
                        ],
                      ),
                    ),
                    actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Tutup'))],
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
