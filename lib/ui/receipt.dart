import 'package:flutter/material.dart';

import '../data/models.dart';

class ReceiptPage extends StatelessWidget {
  final List<CartItem> cartItems;
  final int totalAmount;
  final String? customerName;
  final DateTime date;

  ReceiptPage({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
    required this.date,
    this.customerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nota')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${date.toString().substring(0, 19)}'),
            if (customerName != null && customerName!.isNotEmpty)
              Text('Pelanggan: $customerName'),
            const SizedBox(height: 16),
            const Text('Daftar Belanja:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: cartItems.length,
                itemBuilder: (_, i) {
                  final item = cartItems[i];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('Qty: ${item.qty} x ${item.product.price}'),
                    trailing: Text((item.qty * item.product.price).toString()),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(totalAmount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur cetak belum tersedia')),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  onPressed: () {
                    Navigator.pop(context);
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
