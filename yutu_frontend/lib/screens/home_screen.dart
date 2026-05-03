import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auction.dart';
import '../providers/auction_provider.dart';
import 'auction_detail_screen.dart';
import 'create_auction_screen.dart';
import '../providers/auth_provider.dart';
import 'watchlist_screen.dart';
import '../utils/currency_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();   

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final auctionProvider = Provider.of<AuctionProvider>(context, listen: false);

      
      if (auctionProvider.auctions.isEmpty) {
        auctionProvider.fetchActiveAuctions(refresh: true);
      }

     
      final token = authProvider.token;
      if (token != null) {
        auctionProvider.fetchWatchlist(token);
      }
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        Provider.of<AuctionProvider>(context, listen: false).fetchActiveAuctions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();     
    super.dispose();
  }

  String _formatTimeLeft(String endTimeStr) {
    try {
      final endTime = DateTime.parse(endTimeStr).toLocal();
      final diff = endTime.difference(DateTime.now());
      if (diff.isNegative) return 'Ended';
      if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inMinutes}m left';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildModernCard(BuildContext context, Auction auction) {
    final displayPrice = auction.currentPrice > 0 ? auction.currentPrice : auction.startingPrice;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AuctionDetailScreen(auction: auction)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
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
                      ? Image.network(
                          auction.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
                  
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final token = Provider.of<AuthProvider>(context, listen: false).token;
                        if (token != null) {
                          Provider.of<AuctionProvider>(context, listen: false).toggleWatchlist(auction.id, token);
                        }
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        radius: 16,
                        // Check if it's watched to color the heart
                        child: Icon(
                          Provider.of<AuctionProvider>(context).watchlistIds.contains(auction.id) 
                              ? Icons.favorite 
                              : Icons.favorite_border, 
                          size: 18, 
                          color: Provider.of<AuctionProvider>(context).watchlistIds.contains(auction.id) 
                              ? Colors.redAccent 
                              : Colors.grey
                        ),
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
                    Text(
                      auction.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                    ),
                    
                    const Spacer(), //  pushes the price and timer to the bottom without overflowing
                    
                    Text(
                      CurrencyFormatter.format(displayPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Flexible( // Safely truncates the text if the screen is too narrow
                          child: Text(
                            _formatTimeLeft(auction.endTime),
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false, 
        title: Row(
          mainAxisSize: MainAxisSize.min, 
          children: const [
            Icon(Icons.gavel, color: Colors.deepPurple, size: 28),
            SizedBox(width: 8),
            Text(
              'Yutu Auctions',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // --- NEW: WATCHLIST SHOPPING CART BADGE ---
        actions: [
          if (Provider.of<AuthProvider>(context).isAuthenticated)
            Consumer<AuctionProvider>(
              builder: (context, provider, child) {
                final count = provider.watchlistIds.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Badge(
                    isLabelVisible: count > 0, // Hides the red dot if watchlist is empty
                    label: Text(
                      count > 99 ? '99+' : count.toString(), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    backgroundColor: Colors.red,
                    offset: const Offset(-4, 4), // Positions the badge perfectly over the heart
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border, color: Colors.deepPurple, size: 28),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const WatchlistScreen()));
                      },
                    ),
                  ),
                );
              },
            ),
        ],
        // ------------------------------------------
      ),
      
      floatingActionButton: Provider.of<AuthProvider>(context).isAuthenticated
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAuctionScreen())),
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label:  Text('sell_item'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null, //
      
      //main body of the app
      body: Consumer<AuctionProvider>(
        builder: (context, auctionProvider, child) {
          
          if (auctionProvider.errorMessage != null && !auctionProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(auctionProvider.errorMessage!),
                  TextButton(
                    onPressed: () => auctionProvider.fetchActiveAuctions(refresh: true),
                    child:  Text('retry'.tr()),
                  )
                ],
              )
            );
          }

          return RefreshIndicator(
            onRefresh: () => auctionProvider.fetchActiveAuctions(refresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        Provider.of<AuctionProvider>(context, listen: false)
                            .setSearchQuery(value.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'search_for_text'.tr(),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  Provider.of<AuctionProvider>(context, listen: false)
                                      .setSearchQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                // --- CATEGORY BAR ---
                SliverToBoxAdapter(
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white, // MOVE IT HERE INSIDE THE DECORATION
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      //list of categories
                      children: ['All', 'Electronics', 'Fashion', 'Collectibles', 'Home', 'Toys', 'Sports', 'Other'].map((category) {
                        final isSelected = auctionProvider.selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            // Nedovolíme kliknout, pokud se právě načítá (zabrání spamu)
                            if (!auctionProvider.isLoading) {
                              auctionProvider.setCategory(category);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.deepPurple.shade50 : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'cat_${category.toLowerCase()}'.tr(), 
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.deepPurple : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // ----------------------------------------

                // content:
                if (auctionProvider.isLoading && auctionProvider.auctions.isEmpty)
                  // První načítání (Zobrazí se spinner uprostřed)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (auctionProvider.auctions.isEmpty)
                  
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No items in ${auctionProvider.selectedCategory}',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => auctionProvider.setCategory('All'),
                            child:  Text('view_categories'.tr()),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  // Běžná Mřížka
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 5 :
                                        MediaQuery.of(context).size.width > 800 ? 4 :
                                        MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 16, 
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildModernCard(context, auctionProvider.auctions[index]);
                        },
                        childCount: auctionProvider.auctions.length,
                      ),
                    ),
                  ),
                
                
                if (auctionProvider.isFetchingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}