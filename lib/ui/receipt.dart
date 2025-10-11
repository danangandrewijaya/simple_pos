import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../data/printer.dart';
import '../main.dart';
import '../state/app_state.dart';

class ReceiptPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final int totalAmount;
  final String? customerName;
  final DateTime date;


  const ReceiptPage({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
    required this.date,
    this.customerName,
  }) : super(key: key);

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}


class _ReceiptPageState extends State<ReceiptPage> {
  Future<void> _printReceipt() async {
    final s = context.read<AppState>();
    final ok = await PrinterService.I.ensureConnected(context, s);
    if (!ok) return; // user cancelled or failed
    await PrinterService.I.printReceiptOK58B(
      items: widget.cartItems,
      total: widget.totalAmount,
      date: widget.date,
      customerName: widget.customerName,
      title: 'NOTA',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nota')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${widget.date.toString().substring(0, 19)}'),
            if (widget.customerName != null && widget.customerName!.isNotEmpty)
              Text('Pelanggan: ${widget.customerName}'),
            const SizedBox(height: 16),
            const Text('Daftar Belanja:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: widget.cartItems.length,
                itemBuilder: (_, i) {
                  final item = widget.cartItems[i];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('Qty: ${item.qty} x ${idr(item.product.price)}'),
                    trailing: Text(idr(item.qty * item.product.price)),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(idr(widget.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak'),
                  onPressed: _printReceipt,
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
