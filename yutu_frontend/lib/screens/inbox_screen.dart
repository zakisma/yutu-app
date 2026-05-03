import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart'; 

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<ChatProvider>(context, listen: false).fetchInbox(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:  Text('inbox'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final inbox = chatProvider.inbox;

          if (inbox.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final token = Provider.of<AuthProvider>(context, listen: false).token!;
              await chatProvider.fetchInbox(token);
            },
            child: ListView.separated(
              itemCount: inbox.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final chat = inbox[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: chat.otherUserImage.isNotEmpty ? NetworkImage(chat.otherUserImage) : null,
                    child: chat.otherUserImage.isEmpty ? const Icon(Icons.person, color: Colors.deepPurple) : null,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat.otherUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${'item_label'.tr()}: ${chat.auctionTitle}', style: TextStyle(color: Colors.deepPurple.shade300, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  onTap: () {
                    // Determine who the other person is based on our own ID
                    final myId = Provider.of<AuthProvider>(context, listen: false).currentUser!.id;
                    final receiverId = (myId == chat.buyerId) ? chat.sellerId : chat.buyerId;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversationId: chat.id,
                          receiverId: receiverId,
                          auctionId: chat.auctionId,
                          receiverName: chat.otherUserName,
                          auctionTitle: chat.auctionTitle,
                        ),
                      ),
                    );
                  },
                );
              },
            )
          );
        },
      ),
    );
  }
}