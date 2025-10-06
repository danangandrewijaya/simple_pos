# Simple POS (Flutter + SQLite)

Aplikasi mobile sederhana untuk stok & transaksi penjualan. Offline-first (SQLite).
## Fitur
- CRUD Produk (nama, SKU, harga, stok)
- Keranjang & Checkout (otomatis kurangi stok)
- Ringkasan penjualan per hari


# Simple POS (Plus) — Flutter + SQLite
Perubahan dari starter:
- Format Rupiah (`intl`)
- Validasi stok & error handling saat checkout
- Edit/Hapus produk (long-press item)
- Riwayat: tap hari untuk lihat transaksi & detail item

## Catatan
- DB SQLite lokal bernama `sales_app.db` otomatis dibuat.
- Untuk Web/Desktop, sesuaikan storage (sqflite tidak native Web).

## UI helpers
SnackBar helper tersedia di `lib/ui/snackbars.dart`.
Contoh penggunaan:

```dart
import 'ui/snackbars.dart';

// di dalam build/context
showAppSnackBar(context, 'Pesan singkat', actionLabel: 'Undo', onAction: () { /* undo */ });
```


# Simple POS — Filter & CSV
Fitur tambahan:
- Pencarian nama/SKU + filter stok menipis (threshold bisa diubah di AppBar).
- Ekspor CSV: `products.csv`, `sales.csv`, `sale_items.csv` ke folder dokumen aplikasi (`exports/`).
- Impor CSV produk (header fleksibel).

Plugin baru: `path_provider`, `csv`, `file_picker`, `intl`.

Catatan: impor transaksi belum tersedia (ekspor saja).
