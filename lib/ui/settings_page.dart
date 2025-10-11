import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/printer.dart';
import '../state/app_state.dart';
import '../ui/snackbars.dart';
import 'customers_page.dart';

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

  Future<void> _saveTitle(AppState s) async {
    final newTitle = _titleC.text.trim();
    await s.saveTitle(newTitle.isEmpty ? appName : newTitle);
    if (mounted) showAppSnackBar(context, 'Judul disimpan');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Umum', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Judul Aplikasi', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleC,
                    maxLength: AppState.maxTitleLength,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Masukkan judul aplikasi',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _saveTitle(s),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _saveTitle(s),
                        child: const Text('Simpan'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          _titleC.text = appName;
                          await s.saveTitle(appName);
                          if (mounted) showAppSnackBar(context, 'Judul direset');
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Printer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(s.selectedPrinterName ?? 'Belum ada printer'),
                  subtitle: Text(s.selectedPrinterAddress ?? '-'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          // choose from bonded and save
                          final devices = await PrinterService.I.getBonded();
                          if (!mounted) return;
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
                        },
                        child: const Text('Ubah'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await PrinterService.I.ensureConnected(context, context.read<AppState>());
                          if (ok) await PrinterService.I.testPrint(header: 'TEST PRINT');
                        },
                        child: const Text('Tes'),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manajemen Customer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersPage())),
            ),
          ),
        ],
      ),
    );
  }
}
