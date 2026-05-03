class Order {
  final int id;
  final int auctionId;
  final int buyerId;
  final double finalAmount;
  final String paymentStatus;

  Order({
    required this.id,
    required this.auctionId,
    required this.buyerId,
    required this.finalAmount,
    required this.paymentStatus,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      auctionId: json['auction_id'],
      buyerId: json['buyer_id'],
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'PENDING',
    );
  }
}