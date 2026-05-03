import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/auction.dart';
import '../constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

class AuctionProvider with ChangeNotifier {
  List<Auction> _auctions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Auction> get auctions => _auctions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery == query) return; 
    _searchQuery = query;
    fetchActiveAuctions(refresh: true); // Instantly reload feed with the search
  }
  
  void setCategory(String category) {
    if (_selectedCategory == category) return; 
    _selectedCategory = category;
    // Okamžitě načteme nová data pro tuto kategorii
    fetchActiveAuctions(refresh: true); 
  }
  // ---------------------------

  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  Future<void> fetchActiveAuctions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
      notifyListeners();
    } else {
      if (!_hasMore || _isFetchingMore) return;
      _isFetchingMore = true;
      notifyListeners();
    }

    _errorMessage = null;

    try {
      // Dynamically build URL based on category and search query
      String url = '${ApiConstants.baseUrl}/auctions?page=$_currentPage&limit=10';
      if (_selectedCategory != 'All') {
        url += '&category=${Uri.encodeComponent(_selectedCategory)}';
      }
      if (_searchQuery.isNotEmpty) {
        url += '&q=${Uri.encodeComponent(_searchQuery)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newAuctions = data.map((json) => Auction.fromJson(json)).toList();

        if (refresh) {
          _auctions = newAuctions;
        } else {
          _auctions.addAll(newAuctions);
        }

        if (newAuctions.length < 10) {
          _hasMore = false;
        } else {
          _currentPage++;
        }
      } else {
        _errorMessage = 'Failed to load auctions';
      }
    } catch (e) {
      _errorMessage = 'Network error: Please check your server';
    }

    _isLoading = false;
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<String?> placeBid(int auctionId, double amount, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auctions/$auctionId/bids'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 201) {
        await fetchActiveAuctions(refresh: true);
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['error'] ?? 'Failed to place bid';
      }
    } catch (e) {
      return 'Network error: Could not reach the server';
    }
  }

  Future<String?> createAuction({
    required String title,
    required String description,
    required String category,
    required double startingPrice,
    required double buyNowPrice,
    required String endTime,
    required List<XFile> images,
    required String token,
  }) async {
    
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

      if (cloudName == null || uploadPreset == null) return 'Configuration error';

      List<String> uploadedUrls = [];
      
      // upload images to Cloudinary
      for (var image in images) {
        final imageBytes = await image.readAsBytes();
        final cloudinaryUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        
        final request = http.MultipartRequest('POST', cloudinaryUrl)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: image.name));

        final cloudResponse = await request.send();
        if (cloudResponse.statusCode == 200) {
          final cloudResponseData = await cloudResponse.stream.bytesToString();
          uploadedUrls.add(jsonDecode(cloudResponseData)['secure_url']);
        } else {
          return 'Failed to upload one or more images';
        }
      }

      // send 1 single request to the backend
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auctions'),
        headers: {
          'Content-Type': 'application/json', 
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          'starting_price': startingPrice,
          'buy_now_price': buyNowPrice, 
          'end_time': endTime,
          'images': uploadedUrls,
        }),
      );

      if (response.statusCode == 201) {
        await fetchActiveAuctions(refresh: true); 
        return null; // Success!
      } else {
        return jsonDecode(response.body)['error'] ?? 'Failed to create auction';
      }
    } catch (e) {
      return 'Network error: $e';
    }
  }
  
  Future<Auction?> getAuctionDetails(int id) async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/auctions/$id'));
      if (response.statusCode == 200) {
        return Auction.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  // --- PAGINATED SELLING STATE ---
  final List<Auction> _myAuctions = [];
  List<Auction> get myAuctions => _myAuctions;
  int _myAuctionsPage = 1;
  bool _myAuctionsHasMore = true;
  bool _isFetchingMyAuctions = false;

  bool get myAuctionsHasMore => _myAuctionsHasMore;
  
  Future<void> fetchMyAuctions(String token, {bool refresh = false}) async {
    if (refresh) {
      _myAuctionsPage = 1;
      _myAuctionsHasMore = true;
      _myAuctions.clear();
      notifyListeners();
    }
    if (!_myAuctionsHasMore || _isFetchingMyAuctions) return;

    _isFetchingMyAuctions = true;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auctions/my?page=$_myAuctionsPage&limit=10'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.length < 10) _myAuctionsHasMore = false; // We hit the end of the DB
        
        final newAuctions = data.map((json) => Auction.fromJson(json)).toList();
        _myAuctions.addAll(newAuctions);
        _myAuctionsPage++;
        notifyListeners();
      }
    } catch (e) {
      // print('Error: $e');
    }
    _isFetchingMyAuctions = false;
  }

  // --- PAGINATED BIDDING STATE ---
  final List<Auction> _biddingAuctions = [];
  List<Auction> get biddingAuctions => _biddingAuctions;
  int _biddingPage = 1;
  bool _biddingHasMore = true;
  bool _isFetchingBidding = false;

  bool get biddingHasMore => _biddingHasMore;
  
  Future<void> fetchBiddingAuctions(String token, {bool refresh = false}) async {
    if (refresh) {
      _biddingPage = 1;
      _biddingHasMore = true;
      _biddingAuctions.clear();
      notifyListeners();
    }
    if (!_biddingHasMore || _isFetchingBidding) return;

    _isFetchingBidding = true;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auctions/bidding?page=$_biddingPage&limit=10'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.length < 10) _biddingHasMore = false;
        
        final newAuctions = data.map((json) => Auction.fromJson(json)).toList();
        _biddingAuctions.addAll(newAuctions);
        _biddingPage++;
        notifyListeners();
      }
    } catch (e) {
      // print('Error: $e');
    }
    _isFetchingBidding = false;
  }

  // --- DELETE AUCTION ---
  Future<String?> deleteAuction(int auctionId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/auctions/$auctionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Remove it from the local UI instantly
        _myAuctions.removeWhere((a) => a.id == auctionId);
        _auctions.removeWhere((a) => a.id == auctionId);
        notifyListeners();
        return null; // Success
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['error'] ?? 'Failed to delete auction.';
      }
    } catch (e) {
      return 'Network error while deleting.';
    }
  }

  // --- WATCHLIST STATE ---
  List<Auction> _watchlist = [];
  List<Auction> get watchlist => _watchlist;
  
  // Helper to easily check if an ID is in the watchlist
  List<int> get watchlistIds => _watchlist.map((a) => a.id).toList();

  Future<void> fetchWatchlist(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auctions/watchlist'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _watchlist = data.map((json) => Auction.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      // print('Error fetching watchlist');
    }
  }

  Future<void> toggleWatchlist(int auctionId, String token) async {
    // Optimistic UI update (feels instantly fast for the user)
    final isCurrentlyWatched = watchlistIds.contains(auctionId);
    if (isCurrentlyWatched) {
      _watchlist.removeWhere((a) => a.id == auctionId);
    } else {
      // Temporarily add a dummy so the heart turns red instantly. 
      // It will be fixed on the next refresh.
      _watchlist.add(auctions.firstWhere((a) => a.id == auctionId)); 
    }
    notifyListeners();

    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auctions/$auctionId/watchlist'),
        headers: {'Authorization': 'Bearer $token'},
      );
      // Re-fetch to ensure sync with server
      await fetchWatchlist(token); 
    } catch (e) {
      // If it fails, fetch original list to undo optimistic update
      fetchWatchlist(token);
    }
  }

  // --- BUY IT NOW LOGIC ---
  Future<String?> buyItNow(int auctionId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auctions/$auctionId/buy-now'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Refresh our lists so the UI removes the item from the active feed
        await fetchActiveAuctions(refresh: true);
        return null; // Success!
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['error'] ?? 'Failed to buy item.';
      }
    } catch (e) {
      return 'Network error.';
    }
  }

}
