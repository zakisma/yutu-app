import 'package:easy_localization/easy_localization.dart';
import '../utils/currency_formatter.dart'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auction_provider.dart';
import '../providers/auth_provider.dart';
import 'auction_detail_screen.dart';
import 'login_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<AuctionProvider>(context, listen: false).fetchWatchlist(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text('account'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text('browsing_as_guest'.tr(), style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                child: Text('login_or_register'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('saved_auctions_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<AuctionProvider>(
        builder: (context, provider, child) {
          if (provider.watchlist.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('no_saved_auctions'.tr(), style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              )
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              childAspectRatio: 0.55,
              crossAxisSpacing: 16, mainAxisSpacing: 16,
            ),
            itemCount: provider.watchlist.length,
            itemBuilder: (context, index) {
              final auction = provider.watchlist[index];
              return _buildSavedCard(context, auction, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildSavedCard(BuildContext context, auction, AuctionProvider provider) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AuctionDetailScreen(auction: auction))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.0, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  auction.images.isNotEmpty
                      ? Image.network(auction.images.first, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image))
                      : Container(color: Colors.grey.shade100, child: const Icon(Icons.image)),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final token = Provider.of<AuthProvider>(context, listen: false).token;
                        if (token != null) provider.toggleWatchlist(auction.id, token);
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9), radius: 16,
                        child: const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auction.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Text(CurrencyFormatter.format(auction.currentPrice > 0 ? auction.currentPrice : auction.startingPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}