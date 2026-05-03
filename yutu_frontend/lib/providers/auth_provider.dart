import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../constants.dart';
import '../models/review.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // --- THE LOGIN METHOD ---
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners(); 

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _token = data['token'];
        _currentUser = User.fromJson(data['user']);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!); 
        await prefs.setString('user_data', jsonEncode(data['user']));
        
        _isLoading = false;
        notifyListeners(); 
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    
    // Vymažeme data z harddisku
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    
    notifyListeners();
  }

  // --- THE AUTO-LOGIN METHOD ---
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Na webu čteme synchronně ze SharedPreferences
    final savedToken = prefs.getString('jwt_token');
    final savedUserData = prefs.getString('user_data');

    if (savedToken != null && savedUserData != null) {
      // instant load from hard drive
      _token = savedToken;
      _currentUser = User.fromJson(jsonDecode(savedUserData));
      notifyListeners();

      // Background sync
      _syncUserSilently(); 

      return true;
    }
    
    await logout();
    return false;
  }

  // --- HELPER METHOD FOR BACKGROUND SYNCING ---
  Future<void> _syncUserSilently() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        // the token is still valid, and we have the freshest user data
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        
        // update the hard drive with the newest data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data));
        
        notifyListeners();
      } else if (response.statusCode == 401) {
        await logout(); // Token expired, force log out
      }
    } catch (e) {
      // nothing if internet is off
    }
  }

  // --- REGISTER ---
  Future<String?> register(String email, String password, String fullName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return null; 
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Registration failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Network error: $e';
    }
  }

  // --- UPDATE PROFILE ---
  Future<String?> updateProfile(String profileImageUrl, String phoneNumber, String address) async {
    if (_token == null) return "Not authenticated";

    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'profile_image_url': profileImageUrl,
          'phone_number': phoneNumber,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        if (_currentUser != null) {
          _currentUser = User(
            id: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            profileImageUrl: profileImageUrl,
            phoneNumber: phoneNumber,
            address: address,
          );
          
          // Save the new profile info to the hard drive so it survives a refresh
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
          
          notifyListeners();
        }
        return null; // Success
      } else {
        return jsonDecode(response.body)['error'] ?? "Update failed";
      }
    } catch (e) {
      return "Network error";
    }
  }  

  // --- REVIEWS ---
  Future<List<Review>> getUserReviews(int userId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/users/$userId/reviews'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Review.fromJson(json)).toList();
      }
    } catch (e) {
      // print('Failed to fetch reviews: $e');
    }
    return [];
  }

  Future<String?> submitReview({
    required int revieweeId,
    required int auctionId,
    required int ratingStars,
    required String comment,
  }) async {
    if (_token == null) return "You must be logged in to leave a review.";

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'reviewee_id': revieweeId,
          'auction_id': auctionId,
          'rating_stars': ratingStars,
          'comment': comment,
        }),
      );

      if (response.statusCode == 201) {
        return null; // Success
      } else {
        return jsonDecode(response.body)['error'] ?? "Failed to submit review";
      }
    } catch (e) {
      return "Network error.";
    }
  }
}