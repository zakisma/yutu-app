package models

// Conversation represents a chat room between a buyer and seller about an item
type Conversation struct {
	ID        int    `json:"id"`
	BuyerID   int    `json:"buyer_id"`
	SellerID  int    `json:"seller_id"`
	AuctionID int    `json:"auction_id"`
	CreatedAt string `json:"created_at"`

	OtherUserName  string `json:"other_user_name,omitempty"`
	OtherUserImage string `json:"other_user_image,omitempty"`
	AuctionTitle   string `json:"auction_title,omitempty"`
	LastMessage    string `json:"last_message,omitempty"`
	UnreadCount    int    `json:"unread_count"`
}

// represents a single chat bubble
type Message struct {
	ID             int    `json:"id"`
	ConversationID int    `json:"conversation_id"`
	SenderID       int    `json:"sender_id"`
	Content        string `json:"content"`
	IsRead         bool   `json:"is_read"`
	CreatedAt      string `json:"created_at"`
}

type CreateMessageRequest struct {
	AuctionID  int    `json:"auction_id" validate:"required,gt=0"`
	ReceiverID int    `json:"receiver_id" validate:"required,gt=0"`
	Content    string `json:"content" validate:"required,max=1000"`
}
