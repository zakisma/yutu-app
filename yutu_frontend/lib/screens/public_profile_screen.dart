import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';

class PublicProfileScreen extends StatelessWidget {
  final int sellerId;
  final String sellerName;

  const PublicProfileScreen({super.key, required this.sellerId, required this.sellerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('seller_profile'.tr(args: [sellerName])),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Review>>(
        future: Provider.of<AuthProvider>(context, listen: false).getUserReviews(sellerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data ?? [];
          
          // Calculate average rating
          double averageRating = 0.0;
          if (reviews.isNotEmpty) {
            averageRating = reviews.fold(0.0, (sum, item) => sum + item.ratingStars) / reviews.length;
          }

          return Column(
            children: [
              // --- HEADER ---
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Colors.deepPurple, child: Icon(Icons.person, size: 40, color: Colors.white)),
                    const SizedBox(height: 16),
                    Text(sellerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 4),
                        Text(
                          reviews.isEmpty ? 'no_reviews_yet'.tr() : '${averageRating.toStringAsFixed(1)} (${'reviews_count'.tr(args: [reviews.length.toString()])})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // --- REVIEWS LIST ---
              Expanded(
                child: reviews.isEmpty
                    ? Center(child: Text('user_no_reviews'.tr(), style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: review.reviewerImage.isNotEmpty ? NetworkImage(review.reviewerImage) : null,
                                        child: review.reviewerImage.isEmpty ? const Icon(Icons.person, size: 16) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Row(
                                        children: List.generate(5, (starIndex) {
                                          return Icon(
                                            starIndex < review.ratingStars ? Icons.star : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(review.comment, style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}