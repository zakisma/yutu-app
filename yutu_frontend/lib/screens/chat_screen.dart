import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId; 
  final int receiverId;
  final int auctionId;
  final String receiverName;
  final String auctionTitle;

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverId,
    required this.auctionId,
    required this.receiverName,
    required this.auctionTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId != null) {
        final token = Provider.of<AuthProvider>(context, listen: false).token!;
        Provider.of<ChatProvider>(context, listen: false).fetchMessages(widget.conversationId!, token);
      } else {
        // Safe clear for a brand new chat
        Provider.of<ChatProvider>(context, listen: false).currentMessages.clear();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    final token = Provider.of<AuthProvider>(context, listen: false).token!;
    final success = await Provider.of<ChatProvider>(context, listen: false).sendMessage(
      auctionId: widget.auctionId,
      receiverId: widget.receiverId,
      content: text,
      token: token,
    );

    if (success) {
      _messageController.clear();
      // NO MORE MANUAL SCROLLING NEEDED
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('failed_to_send_msg'.tr()), backgroundColor: Colors.red));
      }
    }
    setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.auctionTitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final messages = chatProvider.currentMessages.reversed.toList();
                
                if (messages.isEmpty) {
                  return Center(child: Text('start_chat_prompt'.tr(), style: const TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  reverse: true, // Tells Flutter to start building from the BOTTOM up
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurple : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        constraints: BoxConstraints(                                     
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- CHAT INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'type_message_hint'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.deepPurple,
                    child: IconButton(
                      icon: _isSending 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}