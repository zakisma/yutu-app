import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat.dart';
import '../constants.dart';

class ChatProvider with ChangeNotifier {
  List<Conversation> _inbox = [];
  List<Message> _currentMessages = [];
  WebSocketChannel? _channel;
  int? _activeConversationId;

  List<Conversation> get inbox => _inbox;
  List<Message> get currentMessages => _currentMessages;

  // --- REST: Fetch Inbox ---
  Future<void> fetchInbox(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/messages/inbox'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _inbox = data.map((json) => Conversation.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching inbox: $e');
    }
  }

  // --- REST: Fetch Message History ---
  Future<void> fetchMessages(int conversationId, String token) async {
    _activeConversationId = conversationId;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/messages/conversations/$conversationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _currentMessages = data.map((json) => Message.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  // --- REST: Send a Message ---
  Future<bool> sendMessage({
    required int auctionId,
    required int receiverId,
    required String content,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'auction_id': auctionId,
          'receiver_id': receiverId,
          'content': content,
        }),
      );

      if (response.statusCode == 201) {
        // Automatically add our own message to the UI instantly
        final newMessage = Message.fromJson(jsonDecode(response.body));
        if (_activeConversationId == newMessage.conversationId || _activeConversationId == null) {
          _currentMessages.add(newMessage);
          notifyListeners();
        }
        
        await fetchInbox(token);
        
        return true;
      }
    } catch (e) {
      print('Error sending message: $e');
    }
    return false;
  }

  // --- WEBSOCKET: Connect & Listen ---
  void connectWebSocket(String token) {
    if (_channel != null) return;

    try {
      final wsBaseUrl = ApiConstants.baseUrl.replaceFirst('http', 'ws');
      final chatWsUrl = '$wsBaseUrl/ws/chat'; 

      _channel = WebSocketChannel.connect(
        Uri.parse(chatWsUrl),
        protocols: [token], // puts token to header Sec-WebSocket-Protocol
      );
      
      _channel!.stream.listen(
        (messageStr) {
          final data = jsonDecode(messageStr);
          if (data['type'] == 'new_message') {
            final incomingMessage = Message.fromJson(data['message']);
            
            // If we are currently looking at this chat, append it to the list
            if (_activeConversationId == incomingMessage.conversationId) {
              _currentMessages.add(incomingMessage);
              notifyListeners();
            }
            // Always refresh the inbox so the preview text updates
            fetchInbox(token);
          }
        },
        onDone: () => disconnectWebSocket(),
        onError: (err) => print('WS Error: $err'),
      );
    } catch (e) {
      print('Could not connect to Chat WS: $e');
    }
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }
}