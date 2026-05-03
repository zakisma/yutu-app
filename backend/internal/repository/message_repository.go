package repository

import (
	"context"
	"database/sql"

	"github.com/zakisma/yutu-app/internal/models"
)

type MessageRepository struct {
	db *sql.DB
}

func NewMessageRepository(db *sql.DB) *MessageRepository {
	return &MessageRepository{db: db}
}

// FindOrCreateConversation ensures a chat room exists between the buyer and seller for an item
func (r *MessageRepository) FindOrCreateConversation(ctx context.Context, buyerID, sellerID, auctionID int) (int, error) {
	var convID int
	query := `SELECT id FROM conversations WHERE buyer_id = $1 AND seller_id = $2 AND auction_id = $3`
	err := r.db.QueryRowContext(ctx, query, buyerID, sellerID, auctionID).Scan(&convID)

	if err == sql.ErrNoRows {
		// Room doesn't exist yet, let's create it!
		insertQuery := `INSERT INTO conversations (buyer_id, seller_id, auction_id) VALUES ($1, $2, $3) RETURNING id`
		err = r.db.QueryRowContext(ctx, insertQuery, buyerID, sellerID, auctionID).Scan(&convID)
	}
	return convID, err
}

// SaveMessage writes the chat bubble to the DB
func (r *MessageRepository) SaveMessage(ctx context.Context, msg *models.Message) error {
	query := `INSERT INTO messages (conversation_id, sender_id, content) VALUES ($1, $2, $3) RETURNING id, created_at`
	return r.db.QueryRowContext(ctx, query, msg.ConversationID, msg.SenderID, msg.Content).Scan(&msg.ID, &msg.CreatedAt)
}

// GetInbox fetches all active chats for a user, complete with the other person's name and latest message
func (r *MessageRepository) GetInbox(ctx context.Context, userID int) ([]*models.Conversation, error) {
	query := `
		SELECT c.id, c.buyer_id, c.seller_id, c.auction_id, a.title,
		       CASE WHEN c.buyer_id = $1 THEN s.full_name ELSE b.full_name END as other_user_name,
		       CASE WHEN c.buyer_id = $1 THEN COALESCE(s.profile_image_url, '') ELSE COALESCE(b.profile_image_url, '') END as other_user_image,
		       COALESCE((SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY created_at DESC LIMIT 1), 'No messages yet') as last_message
		FROM conversations c
		JOIN users b ON c.buyer_id = b.id
		JOIN users s ON c.seller_id = s.id
		JOIN auctions a ON c.auction_id = a.id
		WHERE c.buyer_id = $1 OR c.seller_id = $1
		ORDER BY c.created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var inbox []*models.Conversation
	for rows.Next() {
		var conv models.Conversation
		err := rows.Scan(
			&conv.ID, &conv.BuyerID, &conv.SellerID, &conv.AuctionID,
			&conv.AuctionTitle, &conv.OtherUserName, &conv.OtherUserImage, &conv.LastMessage,
		)
		if err == nil {
			inbox = append(inbox, &conv)
		}
	}
	return inbox, nil
}

// GetMessages fetches the full history of a single chat room
func (r *MessageRepository) GetMessages(ctx context.Context, conversationID int) ([]*models.Message, error) {
	query := `SELECT id, conversation_id, sender_id, content, is_read, created_at FROM messages WHERE conversation_id = $1 ORDER BY created_at ASC`
	rows, err := r.db.QueryContext(ctx, query, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []*models.Message
	for rows.Next() {
		var msg models.Message
		err := rows.Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content, &msg.IsRead, &msg.CreatedAt)
		if err == nil {
			messages = append(messages, &msg)
		}
	}
	return messages, nil
}
