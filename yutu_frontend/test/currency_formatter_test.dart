import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yutu_frontend/utils/currency_formatter.dart'; 

void main() {
  setUpAll(() async {
    await initializeDateFormatting('cs_CZ', null);
  });

  group('Currency Formatter Tests', () {
    test('Formats standard integer to CZK', () {
      final result = CurrencyFormatter.format(50400.0);
      
      // Note: The intl package uses a non-breaking space (\u00A0) for Czech numbers
      // so "50 400 Kč" is actually "50\u00A0400\u00A0Kč" in computer memory!
      final expected = '50\u00A0400\u00A0Kč';
      
      expect(result, equals(expected));
    });

    test('Drops decimals for clean auction pricing', () {
      final result = CurrencyFormatter.format(150.99);
      final expected = '151\u00A0Kč'; // It should round up!
      
      expect(result, equals(expected));
    });

    test('Handles zero correctly', () {
      final result = CurrencyFormatter.format(0.0);
      final expected = '0\u00A0Kč';
      
      expect(result, equals(expected));
    });
  });
}