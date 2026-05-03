import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../constants.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart'; 

class OrderProvider with ChangeNotifier {
  List<Order> _pendingOrders = [];
  bool _isLoading = false;

  List<Order> get pendingOrders => _pendingOrders;
  bool get isLoading => _isLoading;

  // Fetch orders that the user needs to pay for
  Future<void> fetchPendingOrders(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/orders/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _pendingOrders = data.map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {
      // print('Error fetching orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
  
  // Submit the payment/checkout
  Future<String?> checkout(int orderId, String address, String token) async {
    try {
      
      // --- BRANCH 1: WEB (Stripe Checkout Redirect) ---
      if (kIsWeb) {
        final sessionResponse = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/create-checkout-session'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (sessionResponse.statusCode != 200) return 'Failed to generate checkout link.';
        
        final urlString = jsonDecode(sessionResponse.body)['url'];
        final url = Uri.parse(urlString);

        //  opens new window with stripe in web
        if (await canLaunchUrl(url)) {
          await launchUrl(url, webOnlyWindowName: '_blank');
          
          // Přidáme zpoždění 15 sekund, aby to působilo jako reálný Webhook,
          // který čeká, až uživatel dokončí platbu na druhé záložce.
          await Future.delayed(const Duration(seconds: 15)); 
          
          await _confirmPaymentToBackend(orderId, address, token, 'STRIPE_WEB');
          return null;
          } else {
          return 'Could not open browser for payment.';
        }
      } 
      
      // --- BRANCH 2: MOBILE/DESKTOP (Native Payment Sheet) ---
      else {
        final intentResponse = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/payment-intent'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (intentResponse.statusCode != 200) return 'Failed to initialize secure payment.';

        final clientSecret = jsonDecode(intentResponse.body)['client_secret'];

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Yutu Auctions',
          ),
        );

        await Stripe.instance.presentPaymentSheet();
        await _confirmPaymentToBackend(orderId, address, token, 'STRIPE_MOBILE');
        return null;
      }

    } on StripeException {
      return 'Payment cancelled or failed.';
    } catch (e) {
      return 'Network error during checkout';
    }
  }

  // Pomocná metoda pro potvrzení platby do Go backendu
  Future<void> _confirmPaymentToBackend(int orderId, String address, String token, String method) async {
    final confirmResponse = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/checkout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'shipping_address': address,
        'payment_method': method, 
      }),
    );

    if (confirmResponse.statusCode == 200) {
      _pendingOrders.removeWhere((order) => order.id == orderId);
      notifyListeners();
    }
  }

  Future<String?> cancelUnpaidOrder(int orderId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/orders/$orderId/cancel-unpaid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Objednávka byla zrušena, odstraníme ji z lokálního seznamu PENDING
        _pendingOrders.removeWhere((o) => o.id == orderId);
        notifyListeners();
        return null; // Úspěch
      } else {
        return jsonDecode(response.body)['error'] ?? "Nepodařilo se zrušit objednávku";
      }
    } catch (e) {
      return "Chyba sítě";
    }
  }
}