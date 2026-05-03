class Conversation {
  final int id;
  final int buyerId;
  final int sellerId;
  final int auctionId;
  final String auctionTitle;
  final String otherUserName;
  final String otherUserImage;
  final String lastMessage;

  Conversation({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.auctionId,
    required this.auctionTitle,
    required this.otherUserName,
    required this.otherUserImage,
    required this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? 0,
      buyerId: json['buyer_id'] ?? 0,
      sellerId: json['seller_id'] ?? 0,
      auctionId: json['auction_id'] ?? 0,
      auctionTitle: json['auction_title'] ?? 'Unknown Item',
      otherUserName: json['other_user_name'] ?? 'Unknown User',
      otherUserImage: json['other_user_image'] ?? '',
      lastMessage: json['last_message'] ?? '',
    );
  }
}

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      conversationId: json['conversation_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}