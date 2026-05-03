import 'package:flutter_test/flutter_test.dart';
// Note: Replace 'yutu_frontend' with your actual Flutter project name if it is different!
import 'package:yutu_frontend/models/auction.dart'; 

void main() {
  group('Auction Model Data Integrity Tests', () {
    
    test('Safely parses integer prices into doubles', () {
      // Simulating raw JSON from the Go backend where prices are whole numbers
      final rawJson = {
        'id': 1,
        'seller_id': 2,
        'seller_name': 'Test User',
        'title': 'Vintage Camera',
        'description': 'A nice camera',
        'category': 'Electronics',
        'starting_price': 100, // Backend sent an INT
        'current_price': 150,  // Backend sent an INT
        'buy_now_price': 0,
        'end_time': '2026-05-01T12:00:00Z',
        'status': 'ACTIVE',
      };

      final auction = Auction.fromJson(rawJson);

      // The test proves Dart successfully converted them to doubles without crashing
      expect(auction.startingPrice, 100.0);
      expect(auction.currentPrice, 150.0);
      expect(auction.startingPrice, isA<double>());
    });

    test('Safely handles missing images and null highest_bidder_id', () {
       // Simulating a brand new auction that has no bids and no images yet
       final rawJson = {
        'id': 1,
        'seller_id': 2,
        'title': 'Test Item',
        'description': 'Test Description',
        'starting_price': 10.0,
        'end_time': '2026-05-01T12:00:00Z',
        'status': 'ACTIVE',
        // Notice how 'images' and 'highest_bidder_id' are completely missing!
      };

      final auction = Auction.fromJson(rawJson);

      // The test proves your model provides safe defaults instead of crashing
      expect(auction.images, isEmpty);
      expect(auction.highestBidderId, isNull);
    });

  });
}