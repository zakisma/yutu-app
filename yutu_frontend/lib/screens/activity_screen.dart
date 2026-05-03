import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auction.dart';
import '../providers/auction_provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import 'auction_detail_screen.dart';
import 'login_screen.dart';
import '../utils/currency_formatter.dart'; 

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _bidsFilter = 'ALL'; 
  String _salesFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<AuctionProvider>(context, listen: false).fetchMyAuctions(token, refresh: true);
        Provider.of<AuctionProvider>(context, listen: false).fetchBiddingAuctions(token, refresh: true);
        Provider.of<OrderProvider>(context, listen: false).fetchPendingOrders(token);
      }
    });
  }

  Future<void> _loadData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      await Provider.of<AuctionProvider>(context, listen: false).fetchBiddingAuctions(token, refresh: true);
      await Provider.of<AuctionProvider>(context, listen: false).fetchMyAuctions(token, refresh: true);
      await Provider.of<OrderProvider>(context, listen: false).fetchPendingOrders(token);
    }
  }

  DateTime _parseDateSafe(String dateStr) {
    try {
      dateStr = dateStr.replaceAll(' +', '+').replaceAll(' -', '-'); 
      return DateTime.parse(dateStr).toLocal();
    } catch (e) {
      return DateTime.now().subtract(const Duration(days: 1)); 
    }
  }

  List<Auction> _filterAndSortAuctions(List<Auction> list, String filter) {
    var filtered = list.where((a) {
      bool isDateFuture = _parseDateSafe(a.endTime).isAfter(DateTime.now());
      bool isActive = a.status.toUpperCase() == 'ACTIVE' && isDateFuture;

      if (filter == 'ALL') return true;
      if (filter == 'ACTIVE') return isActive;
      return !isActive; 
    }).toList();

    filtered.sort((a, b) {
      bool aActive = a.status.toUpperCase() == 'ACTIVE' && _parseDateSafe(a.endTime).isAfter(DateTime.now());
      bool bActive = b.status.toUpperCase() == 'ACTIVE' && _parseDateSafe(b.endTime).isAfter(DateTime.now());
      
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;

      DateTime aDate = _parseDateSafe(a.endTime);
      DateTime bDate = _parseDateSafe(b.endTime);
      return bDate.compareTo(aDate); 
    });

    return filtered;
  }

  Widget _buildAuctionList(List<Auction> auctions, String emptyMessageKey, {required bool isSellingTab}) {
    if (auctions.isEmpty) {
      return Center(child: Text(emptyMessageKey.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey)));
    }

    final provider = Provider.of<AuctionProvider>(context, listen: false);
    final bool hasMore = (isSellingTab ? provider.myAuctionsHasMore : provider.biddingHasMore) && auctions.length >= 10;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
          final token = Provider.of<AuthProvider>(context, listen: false).token;
          if (token != null && hasMore) { 
            if (isSellingTab) {
              provider.fetchMyAuctions(token);
            } else {
              provider.fetchBiddingAuctions(token);
            }
          }
        }
        return false;
      },
      child: RefreshIndicator(
        color: Colors.deepPurple,
        onRefresh: _loadData,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(), 
          padding: const EdgeInsets.all(12),
          itemCount: auctions.length + (hasMore ? 1 : 0), 
          itemBuilder: (context, index) {
            
            if (index == auctions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }

            final auction = auctions[index];
            final bool isDateFuture = _parseDateSafe(auction.endTime).isAfter(DateTime.now());
            final bool isActive = auction.status.toUpperCase() == 'ACTIVE' && isDateFuture;

            final orderProvider = Provider.of<OrderProvider>(context, listen: false);
            final myUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
            
            final pendingOrder = orderProvider.pendingOrders.where((o) => o.auctionId == auction.id).firstOrNull;
            
            // WINNER LOGIC
            final bool isWinner = auction.highestBidderId == myUserId || (pendingOrder != null && pendingOrder.buyerId == myUserId);
            
            // PAYMENT LOGIC
            final bool needsPayment = pendingOrder != null && !isSellingTab && isWinner;
            final bool hasPaid = !needsPayment && !isSellingTab && isWinner && auction.status.toUpperCase() == 'SOLD';
            
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), 
                side: BorderSide(
                  color: needsPayment ? Colors.red.shade200 : (hasPaid ? Colors.green.shade200 : Colors.grey.shade200), 
                  width: needsPayment || hasPaid ? 2 : 1
                )
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: auction.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(auction.images.first, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.broken_image, color: Colors.grey))),
                      )
                    : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: Colors.grey)),
                
                title: Text(auction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.format(auction.currentPrice > 0 ? auction.currentPrice : auction.startingPrice), style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                      child: Text(isActive ? 'status_active'.tr() : 'status_ended'.tr(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.grey.shade600)),
                    )
                  ],
                ),
                
                trailing: needsPayment
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                        onPressed: () => _showCheckoutDialog(pendingOrder!.id, pendingOrder.finalAmount),
                        child: Text('pay'.tr()),
                      )
                    : hasPaid
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                            child: const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        : (isSellingTab && pendingOrder != null) 
                            // --- NOVÉ: TLAČÍTKO PRO ZRUŠENÍ NEZAPLACENÉ OBJEDNÁVKY ---
                            ? OutlinedButton(
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Zrušit objednávku?'),
                                      content: const Text('Kupující nezaplatil. Chcete tuto objednávku zrušit? Následně budete moci kupujícímu zanechat negativní recenzi.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel'.tr())),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => Navigator.pop(c, true),
                                          child: const Text('Zrušit'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    final token = Provider.of<AuthProvider>(context, listen: false).token!;
                                    final error = await orderProvider.cancelUnpaidOrder(pendingOrder.id, token);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error ?? 'Objednávka byla zrušena.'), backgroundColor: error == null ? Colors.green : Colors.red),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Zrušit (Nezaplaceno)', style: TextStyle(fontSize: 10)),
                              )
                            
                            : (isSellingTab && isActive)
                                ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(context, auction.id))
                                : const Icon(Icons.chevron_right, color: Colors.grey),
                                
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AuctionDetailScreen(auction: auction))),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int auctionId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_auction'.tr()),
        content: Text('delete_auction_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final token = Provider.of<AuthProvider>(context, listen: false).token!;
      final error = await Provider.of<AuctionProvider>(context, listen: false).deleteAuction(auctionId, token);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'auction_deleted_success'.tr()), backgroundColor: error == null ? Colors.green : Colors.red),
        );
      }
    }
  }

  void _showCheckoutDialog(int orderId, double amount) {
    final addressController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('complete_checkout'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${'amount_due'.tr()}: ${CurrencyFormatter.format(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(controller: addressController, decoration: InputDecoration(labelText: 'shipping_addr'.tr(), border: const OutlineInputBorder()), maxLines: 2),
                  const SizedBox(height: 16),
                  Text('payment_method_stripe'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(onPressed: isProcessing ? null : () => Navigator.pop(context), child: Text('cancel'.tr().toUpperCase())),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isProcessing ? null : () async {
                    if (addressController.text.trim().isEmpty) return;
                    setDialogState(() => isProcessing = true);
                    final token = Provider.of<AuthProvider>(context, listen: false).token!;
                    final error = await Provider.of<OrderProvider>(context, listen: false).checkout(orderId, addressController.text.trim(), token);

                    if (!context.mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error ?? 'payment_success'.tr()), backgroundColor: error == null ? Colors.green : Colors.red),
                    );
                    _loadData(); // Reload to hide the pay button
                  },
                  child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text('pay_now'.tr()),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildFilterChips(String currentFilter, Function(String) onSelected) {
    final Map<String, String> filterNames = {
      'ALL': 'filter_all'.tr(),
      'ACTIVE': 'filter_active'.tr(),
      'ENDED': 'filter_ended'.tr(),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: ['ALL', 'ACTIVE', 'ENDED'].map((filterCode) {
          final isSelected = currentFilter == filterCode;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filterNames[filterCode]!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => onSelected(filterCode),
              selectedColor: Colors.deepPurple.shade50,
              labelStyle: TextStyle(color: isSelected ? Colors.deepPurple : Colors.black87),
              showCheckmark: false,
              side: BorderSide(color: isSelected ? Colors.deepPurple : Colors.grey.shade300),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('account'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white),
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
    
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('activity_tab'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            indicatorColor: Colors.deepPurple,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'my_bids'.tr()),
              Tab(text: 'my_listings'.tr()),
            ],
          ),
        ),
        body: Consumer<AuctionProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) return const Center(child: CircularProgressIndicator());

            final filteredBids = _filterAndSortAuctions(provider.biddingAuctions, _bidsFilter);
            final filteredSales = _filterAndSortAuctions(provider.myAuctions, _salesFilter);

            return TabBarView(
              children: [
                Column(
                  children: [
                    _buildFilterChips(_bidsFilter, (val) => setState(() => _bidsFilter = val)),
                    Expanded(child: _buildAuctionList(filteredBids, 'no_bids_yet', isSellingTab: false)),
                  ],
                ),
                Column(
                  children: [
                    _buildFilterChips(_salesFilter, (val) => setState(() => _salesFilter = val)),
                    Expanded(child: _buildAuctionList(filteredSales, 'no_listings_yet', isSellingTab: true)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}