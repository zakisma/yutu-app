class Auction {
  final int id;
  final int sellerId;
  final String sellerName;
  final String title;
  final String description;
  final String category;
  final double currentPrice;
  final double startingPrice;
  final double buyNowPrice;
  final String endTime;
  final List<String> images;
  final String status;
  final int? highestBidderId;

  Auction({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.category,
    required this.currentPrice,
    this.buyNowPrice = 0.0,
    required this.startingPrice,
    required this.endTime,
    required this.images,
    required this.status,
    this.highestBidderId,
  });

  factory Auction.fromJson(Map<String, dynamic> json) {
    return Auction(
      id: json['id'],
      sellerId: json['seller_id'],
      sellerName: json['seller_name'] ?? 'Unknown Seller',
      title: json['title'],
      description: json['description'],
      category: json['category'] ?? '',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      startingPrice: (json['starting_price'] ?? 0).toDouble(),
      buyNowPrice: (json['buy_now_price'] as num?)?.toDouble() ?? 0.0,
      endTime: json['end_time'],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      status: json['status'],
      highestBidderId: json['highest_bidder_id'],
    );
  }
}