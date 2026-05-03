import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auction.dart';
import '../providers/auction_provider.dart';
import '../providers/order_provider.dart'; // <--- IMPORT THIS!
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'public_profile_screen.dart';
import '../utils/currency_formatter.dart'; 

class AuctionDetailScreen extends StatefulWidget {
  final Auction auction;
  const AuctionDetailScreen({super.key, required this.auction});

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  final _bidController = TextEditingController();
  final _commentController = TextEditingController(); 
  bool _isBidding = false;
  late Auction _currentAuction;

  late WebSocketChannel _channel;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _currentAuction = widget.auction; 
    _loadFullDetails(); 
    _connectWebSocket();
    
    // Fetch pending orders so we know if this is paid or not
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<OrderProvider>(context, listen: false).fetchPendingOrders(token);
      }
    });
  }

  @override
  void dispose() {
    _bidController.dispose();
    _channel.sink.close();
    _commentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double _getDynamicIncrement(double currentPrice) {
    if (currentPrice < 100) return 5.0;
    if (currentPrice < 500) return 10.0;
    if (currentPrice < 1000) return 20.0;
    if (currentPrice < 5000) return 50.0;
    if (currentPrice < 10000) return 100.0;
    return 200.0;
  }

  double get _minNextBid {
    return _currentAuction.highestBidderId == null
        ? _currentAuction.startingPrice
        : _currentAuction.currentPrice + _getDynamicIncrement(_currentAuction.currentPrice);
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConstants.wsUrl));
      _channel.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['auction_id'] == _currentAuction.id) {
            if (mounted) {
              setState(() {
                _currentAuction = Auction(
                  id: _currentAuction.id,
                  sellerId: _currentAuction.sellerId,
                  sellerName: _currentAuction.sellerName,
                  title: _currentAuction.title,
                  description: _currentAuction.description,
                  category: _currentAuction.category,
                  currentPrice: (data['new_price'] as num).toDouble(), 
                  highestBidderId: data['highest_bidder_id'] as int?,
                  startingPrice: _currentAuction.startingPrice,
                  endTime: _currentAuction.endTime,
                  images: _currentAuction.images,
                  status: _currentAuction.status,
                );
              });
              
              // final myUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
              final int? myUserId = Provider.of<AuthProvider>(context).currentUser?.id;
              
              if (data['bidder_id'] != myUserId) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('new_bid_placed'.tr()), backgroundColor: Colors.blue),
                );
              }
            }
          }
        },
        onError: (error) {},
        cancelOnError: true,
      );
    } catch (e) {}
  }

  Future<void> _loadFullDetails() async {
    final details = await Provider.of<AuctionProvider>(context, listen: false).getAuctionDetails(_currentAuction.id);
    if (details != null && mounted) {
      setState(() {
        _currentAuction = details;
        
        if (_bidController.text.isEmpty || 
            double.tryParse(_bidController.text) == null || 
            double.parse(_bidController.text) < _minNextBid) {
          _bidController.text = _minNextBid.toStringAsFixed(0);
        }
      });
    }
  }

  Future<void> _submitBid() async {
    final amount = double.tryParse(_bidController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('enter_valid_number'.tr())));
      return;
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isBidding = true);
    final error = await Provider.of<AuctionProvider>(context, listen: false).placeBid(_currentAuction.id, amount, token);
    
    if (!mounted) return;
    setState(() => _isBidding = false);

    if (error == null) {
      ScaffoldMessenger.of(context).clearSnackBars(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('bid_placed_success'.tr()), backgroundColor: Colors.green, duration: const Duration(seconds: 2))
      );
      
      _bidController.clear(); 
      _loadFullDetails(); 
      Provider.of<AuctionProvider>(context, listen: false).fetchBiddingAuctions(token, refresh: true);
      
    } else {
      ScaffoldMessenger.of(context).clearSnackBars(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red, duration: const Duration(seconds: 2))
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      dateStr = dateStr.replaceAll(' +', '+').replaceAll(' -', '-');
      return DateTime.parse(dateStr).toLocal().toString().split('.')[0];
    } catch (e) {
      return dateStr;
    }
  }
  
  Future<void> _handleBuyItNow() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_purchase'.tr()),
        content: Text('${'confirm_buy_now_desc'.tr()} ${CurrencyFormatter.format(_currentAuction.buyNowPrice)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('buy_it_now'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final error = await Provider.of<AuctionProvider>(context, listen: false).buyItNow(_currentAuction.id, token);

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('purchase_successful'.tr()), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  void _showReviewDialog(int targetUserId, String targetUserName) {
    int selectedStars = 5;
    bool isSubmitting = false;
    _commentController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${'rate_seller'.tr()} $targetUserName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(index < selectedStars ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                        onPressed: () => setDialogState(() => selectedStars = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(labelText: 'write_review'.tr(), border: const OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: Text('cancel'.tr())),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isSubmitting ? null : () async {
                    if (_commentController.text.trim().isEmpty) return;
                    
                    setDialogState(() => isSubmitting = true);
                    final error = await Provider.of<AuthProvider>(context, listen: false).submitReview(
                      revieweeId: targetUserId, // Odesíláme ID toho správného uživatele
                      auctionId: _currentAuction.id,
                      ratingStars: selectedStars,
                      comment: _commentController.text.trim(),
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error ?? 'review_success'.tr()),
                      backgroundColor: error == null ? Colors.green : Colors.red,
                    ));
                  },
                  child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text('submit'.tr()),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayPrice = _currentAuction.currentPrice > 0 ? _currentAuction.currentPrice : _currentAuction.startingPrice;
    final theme = Theme.of(context);
    
    bool isDateFuture = true;
    try {
      isDateFuture = DateTime.parse(_currentAuction.endTime.replaceAll(' +', '+').replaceAll(' -', '-')).toLocal().isAfter(DateTime.now());
    } catch (e) {}
    final bool isActive = _currentAuction.status.toUpperCase() == 'ACTIVE' && isDateFuture;
    
    final myUserId = Provider.of<AuthProvider>(context).currentUser?.id;
    final pendingOrder = Provider.of<OrderProvider>(context).pendingOrders.where((o) => o.auctionId == _currentAuction.id).firstOrNull;
    
    // final isWinning = myUserId != null && (_currentAuction.highestBidderId == myUserId || pendingOrder?.buyerId == myUserId);
    final isWinning = myUserId != null && 
                      _currentAuction.status != 'CANCELLED' && 
                      (_currentAuction.highestBidderId == myUserId || pendingOrder?.buyerId == myUserId);

    // If they won, they participated
    final isParticipating = myUserId != null && (isWinning || Provider.of<AuctionProvider>(context).biddingAuctions.any((a) => a.id == _currentAuction.id));
    final isLosing = isParticipating && !isWinning;
    
    // If they won, and it's sold, and it's missing from pendingOrders, they paid
    final hasPaid = isWinning && _currentAuction.status.toUpperCase() == 'SOLD' && pendingOrder == null;
    // ---------------------------
                      
    return Scaffold(
      appBar: AppBar(
        title: Text('item_details'.tr()),
        backgroundColor: Colors.white,
        actions: [
          Consumer<AuctionProvider>(
            builder: (context, provider, child) {
              final isAuthenticated = Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
              final isWatched = isAuthenticated && provider.watchlistIds.contains(_currentAuction.id);

              return IconButton(
                icon: Icon(
                  isWatched ? Icons.favorite : Icons.favorite_border,
                  color: isWatched ? Colors.redAccent : Colors.grey,
                ),
                onPressed: () {
                  final token = Provider.of<AuthProvider>(context, listen: false).token;
                  if (token != null) {
                    provider.toggleWatchlist(_currentAuction.id, token);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('login_watchlist_prompt'.tr()))
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(
                    height: 350,
                    width: double.infinity,
                    child: _currentAuction.images.isNotEmpty
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) => setState(() => _currentImageIndex = index),
                                itemCount: _currentAuction.images.length,
                                itemBuilder: (context, index) {
                                  return Image.network(
                                    _currentAuction.images[index],
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                  );
                                },
                              ),
                              if (_currentAuction.images.length > 1 && _currentImageIndex > 0)
                                Positioned(
                                  left: 16,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
                                    onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  ),
                                ),
                              if (_currentAuction.images.length > 1 && _currentImageIndex < _currentAuction.images.length - 1)
                                Positioned(
                                  right: 16,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.black87),
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
                                    onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('no_image_available'.tr(), style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),

                  if (_currentAuction.images.length > 1)
                    Container(
                      height: 80,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_currentAuction.images.length, (index) {
                            final isSelected = _currentImageIndex == index;
                            return GestureDetector(
                              onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    _currentAuction.images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_currentAuction.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${'category_label'.tr()} ${'cat_${_currentAuction.category.toLowerCase()}'.tr()}', 
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (Provider.of<AuthProvider>(context).isAuthenticated && _currentAuction.sellerId != myUserId)
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.deepPurple),
                              tooltip: 'message_seller'.tr(),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  receiverId: _currentAuction.sellerId,
                                  auctionId: _currentAuction.id,
                                  receiverName: _currentAuction.sellerName,
                                  auctionTitle: _currentAuction.title,
                                )
                              )),
                            ),
                            
                          TextButton.icon(
                            icon: const Icon(Icons.person_outline, color: Colors.deepPurple),
                            label: Text('profile_tab'.tr(), style: const TextStyle(color: Colors.deepPurple)), 
                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (context) => PublicProfileScreen(
                                sellerId: _currentAuction.sellerId, 
                                sellerName: _currentAuction.sellerName,
                              )
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isWinning)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                isActive 
                                    ? 'winning'.tr() 
                                    : (hasPaid ? 'won_and_paid'.tr() : 'won'.tr()), // Displays PAID if they paid
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)
                              ),
                            )
                          else if (isLosing && isActive)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text('losing'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                            ),
                          
                          Text('current_price'.tr(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          Text(CurrencyFormatter.format(displayPrice),  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87),),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              Icon(isActive ? Icons.access_time : Icons.gavel, size: 16, color: isActive ? Colors.redAccent : Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                isActive 
                                    ? '${'ends_at'.tr()} ${_formatDate(_currentAuction.endTime)}' 
                                    : '${'auction_ended'.tr()} (${_currentAuction.status.tr()})',
                                style: TextStyle(
                                  color: isActive ? Colors.redAccent : Colors.grey, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          
                          if (isActive)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_currentAuction.buyNowPrice > 0 && _currentAuction.highestBidderId == null) ...[  
                                  OutlinedButton(
                                    onPressed: () {
                                      if (Provider.of<AuthProvider>(context, listen: false).isAuthenticated) {
                                        _handleBuyItNow();
                                      } else {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: const BorderSide(color: Colors.deepPurple, width: 2),
                                    ),
                                    child: Text(
                                      '${'buy_it_now_for'.tr()} ${CurrencyFormatter.format(_currentAuction.buyNowPrice)}', 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('or'.tr(), style: const TextStyle(color: Colors.grey))), const Expanded(child: Divider())],
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (Provider.of<AuthProvider>(context).isAuthenticated)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${'minimum_bid'.tr()} ${CurrencyFormatter.format(_minNextBid)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: _bidController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              decoration: const InputDecoration(
                                                suffixText: ' Kč', 
                                                suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 3,
                                            child: ElevatedButton(
                                              onPressed: _isBidding ? null : _submitBid,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.deepPurple, 
                                                padding: const EdgeInsets.symmetric(vertical: 20)
                                              ),
                                              child: _isBidding 
                                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                                  : Text('place_bid'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20)),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                                    child: Text('login_to_bid'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // gray container with state of the auction
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _currentAuction.status == 'CANCELLED' ? Colors.red.shade50 : Colors.grey.shade200, 
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentAuction.status == 'SOLD' ? 'item_sold'.tr() : 
                                      (_currentAuction.status == 'CANCELLED' ? '' : 'item_ended'.tr()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: _currentAuction.status == 'CANCELLED' ? Colors.red : Colors.grey, 
                                        fontSize: 16
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // button for review and profile of the buyer/seller
                                Builder(
                                  builder: (context) {
                                    final bool canReview = 
                                      (_currentAuction.status == 'SOLD' && myUserId != null && (_currentAuction.sellerId == myUserId || _currentAuction.highestBidderId == myUserId)) ||
                                      (_currentAuction.status == 'CANCELLED' && myUserId != null && _currentAuction.sellerId == myUserId);

                                    if (canReview) {
                                      final isSeller = myUserId == _currentAuction.sellerId;
                                      
                                      final targetUserId = isSeller ? (_currentAuction.highestBidderId ?? 0) : _currentAuction.sellerId;
                                      final targetUserName = isSeller ? 'buyer'.tr() : _currentAuction.sellerName;
                                      print('--- DEBUG RECENZE 2 ---');
                                      // print('Můj ID (targetuserid): $targetUserName (Typ: ${targetUserName.runtimeType})');
                                      // print('ID Prodejce (sellerId): ${_currentAuction.sellerId} (Typ: ${_currentAuction.sellerId.runtimeType})');
                                      // print('ID Kupujícího (highestBidderId): ${_currentAuction.highestBidderId}');
                                      // print('---------------------');

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 16),
                                          
                                          // button for review leaving
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16), 
                                              side: const BorderSide(color: Colors.amber)
                                            ),
                                            icon: const Icon(Icons.star, color: Colors.amber),
                                            label: Text('${'leave_review_for'.tr()} $targetUserName', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                            onPressed: () => _showReviewDialog(targetUserId, targetUserName), 
                                          ),
                                          
                                          const SizedBox(height: 8),
                                          
                                         // show proifle button
                                          TextButton.icon(
                                            icon: const Icon(Icons.person, color: Colors.deepPurple),
                                            // label: Text('Zobrazit profil ($targetUserName)', style: const TextStyle(color: Colors.deepPurple)),
                                            label: Text('${'view_profile_of_buyer'.tr()} ($targetUserName)', style: const TextStyle(color: Colors.deepPurple),),
                                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                                              builder: (context) => PublicProfileScreen(
                                                sellerId: targetUserId, 
                                                sellerName: targetUserName,
                                              )
                                            )),
                                          ),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink(); 
                                  }
                                )
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('item_description'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(_currentAuction.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}