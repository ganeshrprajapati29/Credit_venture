import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _num = NumberFormat.decimalPattern('en_IN');

String inr(num? v) => v == null ? '—' : _inr.format(v);
String inrPlain(num? v) => v == null ? '' : _num.format(v);

String fmtDate(dynamic d) {
  final dt = d is DateTime ? d : DateTime.tryParse('${d ?? ''}');
  if (dt == null) return '—';
  return DateFormat('dd MMM yyyy').format(dt.toLocal());
}

String fmtDateTime(dynamic d) {
  final dt = d is DateTime ? d : DateTime.tryParse('${d ?? ''}');
  if (dt == null) return '—';
  return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
}

String titleCase(String? s) => (s ?? '')
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

num? asNum(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

/// Safe nested map read: get(loan, 'offer.amount')
dynamic dig(dynamic m, String path) {
  dynamic cur = m;
  for (final k in path.split('.')) {
    if (cur is Map && cur.containsKey(k)) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

class Validators {
  static final mobile = RegExp(r'^[6-9]\d{9}$');
  static final pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final pincode = RegExp(r'^[1-9]\d{5}$');
  static final email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final name = RegExp(r"^[A-Za-z][A-Za-z .'-]{0,59}$");
  static final account = RegExp(r'^\d{9,18}$');

  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? Function(String?) pattern(RegExp rx, String msg, {bool optional = false}) => (v) {
        if (v == null || v.trim().isEmpty) return optional ? null : msg;
        return rx.hasMatch(v.trim()) ? null : msg;
      };

  /// Verhoeff checksum for Aadhaar.
  static bool aadhaar(String n) {
    if (!RegExp(r'^[2-9]\d{11}$').hasMatch(n)) return false;
    const d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];
    const p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];
    var c = 0;
    final digits = n.split('').reversed.map(int.parse).toList();
    for (var i = 0; i < digits.length; i++) {
      c = d[c][p[i % 8][digits[i]]];
    }
    return c == 0;
  }
}
