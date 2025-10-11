// lib/main.dart
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'data/money.dart';
import 'data/printer.dart';
import 'state/app_state.dart';
import 'ui/receipt.dart';
import 'ui/snackbars.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  // Load saved printer selection safely before runApp (requires binding initialized)
  try { await PrinterService.I.loadSelectedFromPrefs(appState); } catch (_) {}
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState..loadProducts()..loadSettings(),
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "$appName " + context.watch<AppState>().appTitle,
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTitle = context.watch<AppState>().appTitle;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/app_icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (appTitle != appName) ...[
              const SizedBox(height: 6),
              Text(
                appTitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 128),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
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
        title: Row(
          children: [
            // Use the app icon asset here so the in-app header matches the launcher icon
            Image.asset(
              'assets/app_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              context.select((AppState s) => s.appTitle),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: pages[idx],
      floatingActionButton: idx == 0
          ? SizedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    onPressed: () => showDialog(context: context, builder: (_) => const AddProductDialog()),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Produk'),
                  ),
                  const SizedBox(width: 12),
                  // export/import small FAB
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      final repo = context.read<AppState>().repo;
                      // Show progress indicator
                      Future<void> showProgress(String msg) async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => AlertDialog(
                            content: Row(children: [
                              const CircularProgressIndicator(),
                              const SizedBox(width: 16),
                              Expanded(child: Text(msg)),
                            ]),
                          ),
                        );
                      }
                      void hideProgress() {
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                      if (v == 'export_products') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Konfirmasi Ekspor'),
                            content: const Text('Ekspor data produk ke file CSV?'),
                            actions: [
                              TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                              FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Ekspor')),
                            ],
                          ),
                        ) ?? false;
                        if (!ok) return;
                        await showProgress('Mengekspor produk...');
                        try {
                          String? dir = await FilePicker.platform.getDirectoryPath();
                          final path = await repo.exportProductsCsv(dir);
                          if (context.mounted) showAppSnackBar(context, 'Produk diekspor ke: $path');
                        } catch (e) {
                          if (context.mounted) showAppSnackBar(context, 'Gagal ekspor: $e');
                        } finally {
                          hideProgress();
                        }
                      } else if (v == 'export_sales') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Konfirmasi Ekspor'),
                            content: const Text('Ekspor data transaksi ke file CSV?'),
                            actions: [
                              TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                              FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Ekspor')),
                            ],
                          ),
                        ) ?? false;
                        if (!ok) return;
                        await showProgress('Mengekspor transaksi...');
                        try {
                          String? dir = await FilePicker.platform.getDirectoryPath();
                          final paths = await repo.exportSalesCsv(dir);
                          if (context.mounted) showAppSnackBar(context, 'Transaksi diekspor ke: ${paths.join(', ')}');
                        } catch (e) {
                          if (context.mounted) showAppSnackBar(context, 'Gagal ekspor: $e');
                        } finally {
                          hideProgress();
                        }
                      } else if (v == 'import_products') {
                        final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
                        if (res!=null && res.files.isNotEmpty) {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Konfirmasi Impor'),
                              content: const Text('Impor produk dari file CSV? Data dengan SKU sama akan ditimpa.'),
                              actions: [
                                TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                                FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Impor')),
                              ],
                            ),
                          ) ?? false;
                          if (!ok) return;
                          await showProgress('Mengimpor produk...');
                          try {
                            final filePath = res.files.single.path!;
                            final n = await context.read<AppState>().repo.importProductsCsv(filePath);
                            await context.read<AppState>().loadProducts();
                            if (context.mounted) showAppSnackBar(context, 'Impor selesai: $n produk');
                          } catch (e) {
                            if (context.mounted) showAppSnackBar(context, 'Gagal impor: $e');
                          } finally {
                            hideProgress();
                          }
                        }
                      }
                    },
                    itemBuilder: (c) => const [
                      PopupMenuItem(value: 'export_products', child: Text('Ekspor CSV - Produk')),
                      PopupMenuItem(value: 'export_sales', child: Text('Ekspor CSV - Transaksi')),
                      PopupMenuItem(value: 'import_products', child: Text('Impor CSV - Produk')),
                    ],
                    child: Row(
                      children: [
                        FloatingActionButton.small(
                          onPressed: null,
                          tooltip: 'Ekspor / Impor',
                          child: const Icon(Icons.swap_horiz),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
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
                            // allow selecting customer from existing customers (optional)
                            final customers = await s.repo.getCustomers();
                            // dedupe customers by id to avoid duplicate Dropdown values
                            final _seen = <int>{};
                            final uniqueCustomers = <Map<String,dynamic>>[];
                            for (final c in customers) {
                              final id = c['id'] as int?;
                              if (id == null) continue;
                              if (_seen.add(id)) uniqueCustomers.add(c);
                            }
                            final codeC = TextEditingController();
                            // selected customer will populate the code/name fields directly
                            final nameC = TextEditingController();
                            int? selectedCustomerId;
                            int selectedMode = 0; // 0 = pilih existing, 1 = input baru
                            final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => StatefulBuilder(builder: (context, setState) {
                                    return AlertDialog(
                                      title: const Text('Simpan Transaksi'),
                                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                                        // Mode selector
                                        RadioListTile<int>(
                                          value: 0,
                                          groupValue: selectedMode,
                                          onChanged: (v) => setState(() => selectedMode = v ?? 0),
                                          title: const Text('Pilih customer dari daftar (disarankan)'),
                                          subtitle: const Text('Gunakan customer yang sudah ada untuk konsistensi'),
                                        ),
                                        if (selectedMode == 0)
                                          // Autocomplete allowing typing to filter customers by name or code
                                          Autocomplete<Map<String, dynamic>>(
                                            displayStringForOption: (c) => '${c['name'] ?? ''} (${c['code']})',
                                            optionsBuilder: (TextEditingValue txt) {
                                              final q = txt.text.trim().toLowerCase();
                                              if (q.isEmpty) return uniqueCustomers;
                                              return uniqueCustomers.where((c) {
                                                final name = (c['name'] as String?)?.toLowerCase() ?? '';
                                                final code = (c['code'] as String?)?.toLowerCase() ?? '';
                                                return name.contains(q) || code.contains(q);
                                              }).toList();
                                            },
                                            onSelected: (c) {
                                              setState(() {
                                                selectedCustomerId = c['id'] as int?;
                                              });
                                              codeC.text = c['code'] ?? '';
                                              nameC.text = c['name'] ?? '';
                                            },
                                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                              // prefill when customer is selected
                                              if (selectedCustomerId != null) {
                                                final sel = uniqueCustomers.firstWhere((e) => e['id'] == selectedCustomerId, orElse: () => {});
                                                if (sel.isNotEmpty) textEditingController.text = '${sel['name'] ?? ''} (${sel['code'] ?? ''})';
                                              }
                                              return TextField(
                                                controller: textEditingController,
                                                focusNode: focusNode,
                                                decoration: const InputDecoration(labelText: 'Customer (ketik untuk cari)'),
                                              );
                                            },
                                          ),

                                        const SizedBox(height: 8),
                                        RadioListTile<int>(
                                          value: 1,
                                          groupValue: selectedMode,
                                          onChanged: (v) => setState(() => selectedMode = v ?? 1),
                                          title: const Text('Input kode & nama baru (opsional)'),
                                          subtitle: const Text('Buat customer baru jika belum ada'),
                                        ),
                                        if (selectedMode == 1)
                                          Column(children: [
                                            TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode Pembeli')), 
                                            const SizedBox(height: 6),
                                            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Pembeli')),
                                          ])
                                        else
                                          // show read-only fields when existing selected to avoid confusion
                                          Column(children: [
                                            TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode Pembeli (otomatis)'), enabled: false),
                                            const SizedBox(height: 6),
                                            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Pembeli (otomatis)'), enabled: false),
                                          ]),
                                      ]),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
                                      ],
                                    );
                                  }),
                                ) ??
                                false;
                            if (!ok) return;
                            try {
                              int? finalCustomerId;
                              if (selectedMode == 0) {
                                finalCustomerId = selectedCustomerId;
                              } else {
                                final code = codeC.text.trim();
                                final name = nameC.text.trim();
                                if (code.isNotEmpty && name.isNotEmpty) {
                                  finalCustomerId = await s.repo.addOrUpdateCustomer(code, name);
                                }
                              }
                              await s.checkout(customerId: finalCustomerId);
                              if (context.mounted) {
                                showAppSnackBar(context, 'Transaksi tersimpan');
                                // Tampilkan receipt langsung setelah checkout
                                if (s.cartBackup?.isNotEmpty == true) {
                                  final cartItems = (s.cartBackup ?? []).map((it) => CartItem(
                                    Product(
                                      id: it.product.id,
                                      name: it.product.name,
                                      price: it.product.price,
                                      stock: it.product.stock,
                                      sku: it.product.sku ?? '',
                                    ),
                                    it.qty,
                                  )).toList();
                                  final totalAmount = cartItems.fold<int>(0, (a, it) => a + it.qty * it.product.price);
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ReceiptPage(
                                      cartItems: cartItems,
                                      totalAmount: totalAmount,
                                      customerName: nameC.text.trim(),
                                      date: DateTime.now(),
                                    ),
                                  ));
                                }
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _titleC;
  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _titleC = TextEditingController(text: s.appTitle);
  }

  @override
  void dispose() {
    _titleC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Judul Aplikasi', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleC,
              maxLength: 30,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Masukkan judul aplikasi',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton(onPressed: () async {
                final newTitle = _titleC.text.trim();
                await s.saveTitle(newTitle.isEmpty ? appName : newTitle);
                if (context.mounted) showAppSnackBar(context, 'Judul disimpan');
              }, child: const Text('Simpan')),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: () async {
                _titleC.text = appName;
                await s.saveTitle(appName);
                if (context.mounted) showAppSnackBar(context, 'Judul direset');
              }, child: const Text('Reset')),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Printer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.print, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.selectedPrinterName != null
                        ? '${s.selectedPrinterName} (${s.selectedPrinterAddress ?? '-'})'
                        : 'Belum ada printer',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    // choose from bonded and save
                    final devices = await PrinterService.I.getBonded();
                    if (context.mounted) {
                      BluetoothDevice? chosen;
                      await showDialog(
                        context: context,
                        builder: (_) => StatefulBuilder(
                          builder: (context, setState) => AlertDialog(
                            title: const Text('Pilih Printer'),
                            content: devices.isEmpty
                                ? const Text('Tidak ada perangkat. Pair di pengaturan Bluetooth dahulu.')
                                : DropdownButton<BluetoothDevice>(
                                    isExpanded: true,
                                    hint: const Text('Pilih perangkat'),
                                    value: chosen,
                                    items: devices
                                        .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text((d.name ?? d.address ?? 'Unknown').toString()),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => chosen = v),
                                  ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                              FilledButton(
                                onPressed: chosen == null
                                    ? null
                                    : () async {
                                        await PrinterService.I.saveSelectedPrinter(
                                          chosen!.name ?? '',
                                          chosen!.address ?? '',
                                          context.read<AppState>(),
                                        );
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                child: const Text('Simpan'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Ubah'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await PrinterService.I.ensureConnected(context, context.read<AppState>());
                    if (ok) await PrinterService.I.testPrint(header: 'TEST PRINT');
                  },
                  child: const Text('Tes'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: s.selectedPrinterAddress == null
                    ? null
                    : () async {
                        await PrinterService.I.clearSelectedPrinter(context.read<AppState>());
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus default printer'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_)=>const CustomersPage())),
              icon: const Icon(Icons.people),
              label: const Text('Manajemen Customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  void _load() {
    _future = context.read<AppState>().repo.getCustomers();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppState>().repo;
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Customer'), actions: [
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: () async {
            final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
            if (res != null && res.files.isNotEmpty) {
              final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                title: const Text('Konfirmasi Impor'),
                content: const Text('Impor CSV akan menimpa customer yang kode-nya sama. Lanjutkan?'),
                actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                          FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Lanjut'))],
              )) ?? false;
              if (!ok) return;
              try {
                final n = await repo.importCustomersCsv(res.files.single.path!);
                setState(_load);
                if (context.mounted) showAppSnackBar(context, 'Impor selesai: $n customer');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, 'Impor gagal: $e');
              }
            }
          },
        ),
      ]),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rows[i];
              return ListTile(
                title: Text(r['name'] ?? ''),
                subtitle: Text(r['code'] ?? ''),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final codeC = TextEditingController(text: r['code'] ?? '');
                      final nameC = TextEditingController(text: r['name'] ?? '');
                      final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                        title: const Text('Edit Customer'),
                        content: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode')),
                          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
                        ]),
                        actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                                  FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Simpan'))],
                      ));
                      if (ok == true) {
                        final newCode = codeC.text.trim();
                        final newName = nameC.text.trim();
                        if (newCode.isEmpty) {
                          if (context.mounted) showAppSnackBar(context, 'Kode tidak boleh kosong');
                          return;
                        }
                        if (newCode != (r['code'] ?? '')) {
                          final existing = await repo.getCustomerByCode(newCode);
                          if (existing != null) {
                            final rep = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                              title: const Text('Konfirmasi'),
                              content: Text('Kode $newCode sudah ada. Ganti data customer?'),
                              actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                                        FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Ganti'))],
                            )) ?? false;
                            if (!rep) return;
                          }
                        }
                        await repo.addOrUpdateCustomer(newCode, newName);
                        setState(_load);
                        if (context.mounted) showAppSnackBar(context, 'Customer disimpan');
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                        title: const Text('Hapus Customer?'),
                        content: Text('Hapus ${r['name'] ?? ''}?'),
                        actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                                  FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Hapus'))],
                      )) ?? false;
                      if (!ok) return;
                      await repo.deleteCustomerById(r['id'] as int);
                      setState(_load);
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final codeC = TextEditingController();
          final nameC = TextEditingController();
          final ok = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
            title: const Text('Tambah Customer'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Kode')),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
            ]),
            actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                      FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Simpan'))],
          ));
          if (ok == true) {
            final code = codeC.text.trim();
            final name = nameC.text.trim();
            if (code.isEmpty) {
              if (context.mounted) showAppSnackBar(context, 'Kode tidak boleh kosong');
              return;
            }
            final existing = await repo.getCustomerByCode(code);
            if (existing != null) {
              final rep = await showDialog<bool>(context: context, builder: (_)=>AlertDialog(
                title: const Text('Konfirmasi'),
                content: Text('Kode $code sudah ada. Ganti data customer?'),
                actions: [TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                          FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Ganti'))],
              )) ?? false;
              if (!rep) return;
            }
            await repo.addOrUpdateCustomer(code, name);
            setState(_load);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
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
              return ListTile(
                title: Text(idr(s['total'])),
                subtitle: Text(time),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if ((s['customer_code'] as String?)?.isNotEmpty ?? false)
                      Text('${s['customer_code']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if ((s['customer_name'] as String?)?.isNotEmpty ?? false)
                      Text('${s['customer_name']}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                onTap: () async {
                  final items = await repo.getSaleItems(s['id'] as int);
                  final int? initialCustomerId = (s['customer_id'] is int) ? s['customer_id'] as int : null;
                  final customers = await repo.getCustomers();
                  final _seen2 = <int>{};
                  final uniqueCustomers2 = <Map<String,dynamic>>[];
                  for (final c in customers) {
                    final id = c['id'] as int?;
                    if (id == null) continue;
                    if (_seen2.add(id)) uniqueCustomers2.add(c);
                  }
                  if (initialCustomerId != null && !uniqueCustomers2.any((e) => e['id'] == initialCustomerId)) {
                    final missing = await repo.getCustomerById(initialCustomerId);
                    if (missing != null) {
                      uniqueCustomers2.insert(0, missing);
                    } else {
                      uniqueCustomers2.insert(0, {'id': initialCustomerId, 'code': 'unknown', 'name': 'Customer #${initialCustomerId} (tidak ditemukan)'});
                    }
                    _seen2.add(initialCustomerId);
                  }
                  int? chosenCustomerId = initialCustomerId;
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Detail Transaksi', style: Theme.of(context).textTheme.titleMedium),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Waktu:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            Text('${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Customer:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            Text((s['customer_name'] ?? '') + ((s['customer_code'] != null && (s['customer_code'] as String).isNotEmpty) ? ' (${s['customer_code']})' : '')),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            Text(idr(s['total'])),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Item:', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ...items.map<Widget>((it) => Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text('${it['name']} x${it['qty']}')),
                                            Text(idr(it['price'] * it['qty'])),
                                          ],
                                        )),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit Customer'),
                                      onPressed: () async {
                                        final saved = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => StatefulBuilder(builder: (context, setState) {
                                            return AlertDialog(
                                              title: const Text('Edit Customer'),
                                              content: Autocomplete<Map<String, dynamic>>(
                                                displayStringForOption: (c) => '${c['name'] ?? ''} (${c['code']})',
                                                optionsBuilder: (TextEditingValue txt) {
                                                  final q = txt.text.trim().toLowerCase();
                                                  if (q.isEmpty) return uniqueCustomers2;
                                                  return uniqueCustomers2.where((c) {
                                                    final name = (c['name'] as String?)?.toLowerCase() ?? '';
                                                    final code = (c['code'] as String?)?.toLowerCase() ?? '';
                                                    return name.contains(q) || code.contains(q);
                                                  }).toList();
                                                },
                                                onSelected: (c) => setState(() => chosenCustomerId = c['id'] as int?),
                                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                                  if (chosenCustomerId != null) {
                                                    final sel = uniqueCustomers2.firstWhere((e) => e['id'] == chosenCustomerId, orElse: () => {});
                                                    if (sel.isNotEmpty) textEditingController.text = '${sel['name'] ?? ''} (${sel['code'] ?? ''})';
                                                  }
                                                  return TextField(
                                                    controller: textEditingController,
                                                    focusNode: focusNode,
                                                    decoration: const InputDecoration(labelText: 'Customer (ketik untuk cari)'),
                                                  );
                                                },
                                              ),
                                              actions: [
                                                TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Batal')),
                                                FilledButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Simpan')),
                                              ],
                                            );
                                          }),
                                        );
                                        if (saved == true) {
                                          await repo.updateSaleCustomer(s['id'] as int, customerId: chosenCustomerId);
                                          setState(_load);
                                          if (context.mounted) showAppSnackBar(context, 'Data customer disimpan');
                                          Navigator.pop(context); // close detail dialog
                                        }
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.receipt_long),
                                      label: const Text('Nota'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => ReceiptPage(
                                            cartItems: items.map((it) => CartItem(
                                              Product(
                                                id: it['product_id'],
                                                name: it['name'],
                                                price: it['price'],
                                                stock: 0,
                                                sku: '',
                                              ),
                                              it['qty'],
                                            )).toList(),
                                            totalAmount: s['total'],
                                            customerName: s['customer_name'],
                                            date: dt,
                                          ),
                                        ));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tutup'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
