import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

/// Formats an amount with the given currency symbol using Indian digit grouping.
String formatMoney(num amount, {String symbol = '₹'}) {
  final neg = amount < 0;
  final s = _inr.format(amount.abs().round());
  return '${neg ? '-' : ''}$symbol$s';
}

String formatDay(DateTime d) => DateFormat('d MMM').format(d);

/// Drops a trailing ".0" so 250.0 shows as "250" but 250.5 stays "250.5".
String trimAmount(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
