import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../ui/snackbars.dart';

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
