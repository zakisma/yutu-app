import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount) {
    final formatCurrency = NumberFormat.currency(
      locale: 'cs_CZ', 
      symbol: 'Kč',    
      decimalDigits: 0,
    );
    return formatCurrency.format(amount);
  }
}