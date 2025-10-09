import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../main.dart';

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
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() async {
    _devices = await bluetooth.getBondedDevices();
    setState(() {});
    bluetooth.isConnected.then((isConnected) {
      setState(() {
        _isConnected = isConnected ?? false;
      });
    });
  }

  void _connectPrinter() async {
    if (_selectedDevice != null) {
      await bluetooth.connect(_selectedDevice!);
      setState(() {
        _isConnected = true;
      });
    }
  }

  void _printReceipt() async {
    if (!_isConnected) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Pilih Printer'),
            content: DropdownButton<BluetoothDevice>(
              hint: const Text('Pilih Printer'),
              value: _selectedDevice,
              items: _devices
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name ?? d.address ?? 'Unknown'),
                      ))
                  .toList(),
              onChanged: (d) {
                setState(() {
                  _selectedDevice = d;
                });
              },
            ),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: const Text('Konek'),
                onPressed: () {
                  if (_selectedDevice != null) {
                    _connectPrinter();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                    _printReceipt(); // lanjut cetak setelah konek
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ],
          );
        },
      );
      return;
    }
    bluetooth.printNewLine();
    bluetooth.printCustom('NOTA', 3, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom('Tanggal: ${widget.date.toString().substring(0, 19)}', 1, 0);
    if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      bluetooth.printCustom('Pelanggan: ${widget.customerName}', 1, 0);
    }
    bluetooth.printNewLine();
    bluetooth.printCustom('Daftar Belanja:', 1, 0);
    for (final item in widget.cartItems) {
      bluetooth.printCustom('${item.product.name}', 1, 0);
      bluetooth.printCustom('  ${item.qty} x ${item.product.price} = ${item.qty * item.product.price}', 1, 0);
    }
    bluetooth.printNewLine();
    bluetooth.printCustom('Total: ${widget.totalAmount}', 2, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
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
                Text(widget.totalAmount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
