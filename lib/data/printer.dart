import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/money.dart';
import '../state/app_state.dart';

/// Simple printer service to manage Bluetooth Thermal printer (OK58B compatible)
class PrinterService {
  PrinterService._();
  static final PrinterService I = PrinterService._();

  final BlueThermalPrinter _bt = BlueThermalPrinter.instance;

  static const _prefPrinterName = 'printer_name';
  static const _prefPrinterAddr = 'printer_address';

  Future<List<BluetoothDevice>> getBonded() async {
    try {
      return await _bt.getBondedDevices();
    } catch (_) {
      return <BluetoothDevice>[];
    }
  }

  Future<bool> get isConnected async => await _bt.isConnected ?? false;

  Future<void> disconnect() async {
    try { await _bt.disconnect(); } catch (_) {}
  }

  Future<bool> connectTo(BluetoothDevice d) async {
    try {
      await _bt.connect(d);
      return await isConnected;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSelectedPrinter(String name, String address, AppState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPrinterName, name);
    await prefs.setString(_prefPrinterAddr, address);
    s.setSelectedPrinter(name, address);
  }

  Future<void> clearSelectedPrinter(AppState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPrinterName);
    await prefs.remove(_prefPrinterAddr);
    s.setSelectedPrinter(null, null);
  }

  Future<void> loadSelectedFromPrefs(AppState s) async {
    final prefs = await SharedPreferences.getInstance();
    s.setSelectedPrinter(prefs.getString(_prefPrinterName), prefs.getString(_prefPrinterAddr));
  }

  Future<bool> connectToSaved(AppState s) async {
    if (s.selectedPrinterAddress == null) return false;
    final list = await getBonded();
    BluetoothDevice? target;
    for (final e in list) {
      final addr = (e.address ?? '').toUpperCase();
      if (addr == s.selectedPrinterAddress!.toUpperCase()) { target = e; break; }
    }
    if (target == null) return false;
    return await connectTo(target);
  }

  /// Ensure connected. If no saved printer or connection fails, prompt to select
  /// a bonded device and optionally save it.
  Future<bool> ensureConnected(BuildContext context, AppState s) async {
    if (await isConnected) return true;
    // Try connect saved printer
    if (await connectToSaved(s)) return true;

    // If none, prompt simple add
    final devices = await getBonded();
    if (context.mounted) {
      BluetoothDevice? chosen;
      bool remember = true;
      final ok = await showDialog<bool>(
            context: context,
            builder: (_) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Pilih Printer'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (devices.isEmpty)
                        const Text('Tidak ada printer terpasang. Pair di pengaturan Bluetooth dahulu.'),
                      if (devices.isNotEmpty)
                        DropdownButton<BluetoothDevice>(
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
                      if (devices.isNotEmpty)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Jadikan default'),
                          value: remember,
                          onChanged: (v) => setState(() => remember = v ?? true),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    FilledButton(
                      onPressed: chosen == null ? null : () => Navigator.pop(context, true),
                      child: const Text('Konek'),
                    ),
                  ],
                );
              },
            ),
          ) ??
          false;
      if (!ok || chosen == null) return false;
      final connected = await connectTo(chosen!);
      if (connected && remember) {
        await saveSelectedPrinter(chosen!.name ?? '', chosen!.address ?? '', s);
      }
      return connected;
    }
    return false;
  }

  /// Simple alignment for 58mm: assume 32 chars per line for default font size.
  String _leftRight(String left, String right, {int width = 32}) {
    left = left.trim();
    right = right.trim();
    final space = width - left.length - right.length;
    if (space <= 0) return left + ' ' + right; // fallback
    return left + ' ' * space + right;
  }

  Future<void> testPrint({String header = 'TEST CETAK'}) async {
    try {
      _bt.printNewLine();
      _bt.printCustom(header, 2, 1);
      _bt.printCustom('OK58B Compatible', 1, 1);
      _bt.printNewLine();
      _bt.printCustom(_leftRight('Contoh', 'Nilai'), 1, 0);
      _bt.printCustom(_leftRight('A', '1'), 1, 0);
      _bt.printCustom(_leftRight('B', '2'), 1, 0);
      _bt.printNewLine();
      _bt.printCustom('Terima kasih', 1, 1);
      _bt.printNewLine();
      _bt.printNewLine();
      try { _bt.paperCut(); } catch (_) {}
    } catch (_) {}
  }

  Future<void> printReceiptOK58B({
    required List<CartItem> items,
    required int total,
    required DateTime date,
    String? customerName,
    String title = 'NOTA',
  }) async {
    // Header
    _bt.printNewLine();
    _bt.printCustom(title, 3, 1);
    _bt.printNewLine();
    final tgl = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    _bt.printCustom('Tanggal: $tgl', 1, 0);
    if (customerName != null && customerName.trim().isNotEmpty) {
      _bt.printCustom('Pelanggan: $customerName', 1, 0);
    }
    _bt.printNewLine();

    // Items
    _bt.printCustom('Daftar Belanja:', 1, 0);
    for (final it in items) {
      final name = it.product.name;
      final line1 = name.length <= 32 ? name : name.substring(0, 32);
      _bt.printCustom(line1, 1, 0);
      final qty = it.qty;
      final price = it.product.price;
      final sub = qty * price;
      _bt.printCustom(_leftRight('  $qty x ${idr(price)}', idr(sub)), 1, 0);
    }
    _bt.printNewLine();
    _bt.printCustom(_leftRight('Total', idr(total)), 2, 0);
    _bt.printNewLine();
    _bt.printCustom('Terima kasih', 1, 1);
    _bt.printNewLine();
    _bt.printNewLine();
    try { _bt.paperCut(); } catch (_) {}
  }
}
