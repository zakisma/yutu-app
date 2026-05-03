class Review {
  final int id;
  final int reviewerId;
  final int revieweeId;
  final int auctionId;
  final int ratingStars;
  final String comment;
  final String createdAt;
  final String reviewerName;
  final String reviewerImage;

  Review({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.auctionId,
    required this.ratingStars,
    required this.comment,
    required this.createdAt,
    required this.reviewerName,
    required this.reviewerImage,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      reviewerId: json['reviewer_id'] ?? 0,
      revieweeId: json['reviewee_id'] ?? 0,
      auctionId: json['auction_id'] ?? 0,
      ratingStars: json['rating_stars'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] ?? '',
      reviewerName: json['reviewer_name'] ?? 'Anonymous',
      reviewerImage: json['reviewer_image'] ?? '',
    );
  }
}