// lib/data/money.dart
import 'package:intl/intl.dart';
final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String idr(num v) => _idr.format(v);
