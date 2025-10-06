// lib/main.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'data/money.dart';
import 'state/app_state.dart';
import 'ui/snackbars.dart';

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
        actions: idx == 0 ? const [ProductsActions()] : null,
      ),
      body: pages[idx],
      floatingActionButton: idx == 0
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(context: context, builder: (_) => const AddProductDialog()),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
    return Row(children: [
      PopupMenuButton<String>(
        onSelected: (v) async {
          final repo = context.read<AppState>().repo;
          if (v == 'export_products') {
            // ask user for target directory; if cancelled, repo will use app exports dir
            String? dir = await FilePicker.platform.getDirectoryPath();
            final path = await repo.exportProductsCsv(dir);
            if (context.mounted) {
              showAppSnackBar(context, 'Produk diekspor ke: $path');
            }
          } else if (v == 'export_sales') {
            String? dir = await FilePicker.platform.getDirectoryPath();
            final paths = await repo.exportSalesCsv(dir);
            if (context.mounted) {
              showAppSnackBar(context, 'Transaksi diekspor ke: ${paths.join(', ')}');
            }
          } else if (v == 'import_products') {
            final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
            if (res!=null && res.files.isNotEmpty) {
              final filePath = res.files.single.path!;
              final n = await repo.importProductsCsv(filePath);
              await context.read<AppState>().loadProducts();
              if (context.mounted) {
                showAppSnackBar(context, 'Impor selesai: $n produk');
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
  void initState() {
    super.initState();
    c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          controller: c,
          onChanged: (v)=>s.loadProducts(v),
          // show clear button when there's text
          // (placed here so decoration can rebuild when controller changes)
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Cari produk...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: c.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: (){ c.clear(); s.loadProducts(''); }) : null,
          ),
        )),
        Expanded(child: ListView.builder(
          itemCount: s.products.length,
          itemBuilder: (_, i) {
            final p = s.products[i];
                final isOut = p.stock == 0;
                Widget buildSubtitle() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SKU: ${p.sku ?? '-'} • Stok: ${p.stock}', style: isOut ? const TextStyle(color: Colors.red) : null),
                      if (isOut) const SizedBox(height: 6),
                      if (isOut)
                        Chip(
                          label: const Text('Stok Habis', style: TextStyle(color: Colors.red)),
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  );
                }

                void handleAdd() {
                  final added = s.addToCart(p);
                  if (!added) {
                    showAppSnackBar(context, 'Stok tidak cukup');
                    return;
                  }
                  final inCart = s.cart.firstWhere((c) => c.product.id == p.id, orElse: () => CartItem(p, 0));
                  final remaining = p.stock - inCart.qty;
                  showAppSnackBar(context, 'Ditambahkan ke keranjang — tersisa $remaining', actionLabel: 'Undo', onAction: (){
                    s.changeQty(p, inCart.qty - 1);
                    showAppSnackBar(context, 'Penambahan dibatalkan');
                  });
                }

                return Opacity(
                  opacity: isOut ? 0.7 : 1.0,
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
                    title: Text(p.name),
                    subtitle: buildSubtitle(),
                    trailing: SizedBox(
                      width: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(child: Text(idr(p.price), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            color: isOut ? Colors.grey : Theme.of(context).colorScheme.primary,
                            onPressed: isOut ? null : handleAdd,
                            tooltip: isOut ? 'Stok habis' : 'Tambah ke keranjang',
                          ),
                        ],
                      ),
                    ),
                    onTap: isOut ? () { showAppSnackBar(context, 'Stok tidak cukup'); } : handleAdd,
                    onLongPress: () => showDialog(context: context, builder: (_) => EditProductDialog(p: p)),
                  ),
                );
          },
        )),
        // bottom add button removed: FAB now provides quick add action
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
        Expanded(
          child: s.cart.isEmpty
              ? const Center(child: Text('Keranjang kosong'))
              : ListView.separated(
                  itemCount: s.cart.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = s.cart[i];
                    final subtotal = it.qty * it.product.price;
                    return Dismissible(
                      key: ValueKey(it.product.id ?? i),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        s.changeQty(it.product, 0);
                        showAppSnackBar(context, 'Item dihapus');
                      },
                      child: ListTile(
                        leading: CircleAvatar(child: Text(it.product.name.isNotEmpty ? it.product.name[0].toUpperCase() : '?')),
                        title: Text(it.product.name),
                        subtitle: Text('${idr(it.product.price)} • Subtotal: ${idr(subtotal)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                final q = (it.qty - 1).clamp(0, 999);
                                s.changeQty(it.product, q);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                final success = s.changeQty(it.product, it.qty + 1);
                                if (!success) showAppSnackBar(context, 'Stok tidak cukup');
                              },
                            ),
                          ],
                        ),
                        onLongPress: () => showDialog(context: context, builder: (_) => EditProductDialog(p: it.product)),
                      ),
                    );
                  },
                ),
        ),

        // Bottom summary bar
        Material(
          elevation: 6,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total'),
                        const SizedBox(height: 4),
                        Text(idr(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: s.cart.isEmpty
                        ? null
                        : () async {
                            final codeC = TextEditingController();
                            final nameC = TextEditingController();
                            final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Simpan Transaksi'),
                                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                                      TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode Pembeli (opsional)')),
                                      TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Pembeli (opsional)')),
                                    ]),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (!ok) return;
                            try {
                              await s.checkout(
                                buyer: nameC.text.isEmpty ? null : nameC.text,
                                buyerCode: codeC.text.isEmpty ? null : codeC.text,
                                buyerName: nameC.text.isEmpty ? null : nameC.text,
                              );
                              if (context.mounted) {
                                showAppSnackBar(context, 'Transaksi tersimpan');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showAppSnackBar(context, '$e');
                              }
                            }
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          ),
        ),
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

class SalesOfDayPage extends StatefulWidget {
  final String day;
  const SalesOfDayPage({super.key, required this.day});
  @override
  State<SalesOfDayPage> createState() => _SalesOfDayPageState();
}

class _SalesOfDayPageState extends State<SalesOfDayPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().repo.getSalesByDay(widget.day);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().repo;
    return Scaffold(
      appBar: AppBar(title: Text('Transaksi ${widget.day}')),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: _future,
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
              final buyerCode = (s['buyer_code'] as String?) ?? '';
              return ListTile(
                title: Text(idr(s['total'])),
                subtitle: Text(time),
                trailing: (buyerName.isNotEmpty || buyerCode.isNotEmpty)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (buyerCode.isNotEmpty) Text(buyerCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (buyerName.isNotEmpty) Text(buyerName, style: const TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
                onTap: () async {
                  final items = await repo.getSaleItems(s['id'] as int);
                  final buyerTextController = TextEditingController(text: (s['buyer'] as String?) ?? '');
                  final buyerCodeController = TextEditingController(text: (s['buyer_code'] as String?) ?? '');
                  // ignore: use_build_context_synchronously
                  final saved = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                    title: const Text('Detail Transaksi'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: buyerCodeController, decoration: const InputDecoration(labelText: 'Kode Pembeli (opsional)')),
                          TextField(controller: buyerTextController, decoration: const InputDecoration(labelText: 'Nama Pembeli (opsional)')),
                          const SizedBox(height: 12),
                          ...items.map((it)=>ListTile(
                            dense: true,
                            title: Text(it['name'] as String),
                            trailing: Text('${it['qty']} x ${idr(it['price'])}'),
                          )).toList(),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Tutup')),
                      FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Simpan')),
                    ],
                  ));
                  if (saved == true) {
                    final code = buyerCodeController.text.isEmpty ? null : buyerCodeController.text;
                    final name = buyerTextController.text.isEmpty ? null : buyerTextController.text;
                    if (code != null && name != null) {
                      await repo.addOrUpdateBuyer(code, name);
                    }
                    await repo.updateSaleBuyer(s['id'] as int, buyer: name, buyerCode: code);
                    // reload list
                    setState(_load);
                    if (context.mounted) showAppSnackBar(context, 'Data pembeli disimpan');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
