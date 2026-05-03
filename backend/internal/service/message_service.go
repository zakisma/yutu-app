package service

import (
	"context"

	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/repository"
	"github.com/zakisma/yutu-app/internal/ws"
)

type MessageService struct {
	repo *repository.MessageRepository
	hub  *ws.ChatHub
}

func NewMessageService(repo *repository.MessageRepository, hub *ws.ChatHub) *MessageService {
	return &MessageService{repo: repo, hub: hub}
}

func (s *MessageService) GetInbox(ctx context.Context, userID int) ([]*models.Conversation, error) {
	return s.repo.GetInbox(ctx, userID)
}

func (s *MessageService) GetMessages(ctx context.Context, conversationID int) ([]*models.Message, error) {
	return s.repo.GetMessages(ctx, conversationID)
}

func (s *MessageService) SendMessage(ctx context.Context, senderID int, req models.CreateMessageRequest) (*models.Message, error) {

	// Ensure the room exists (Ww pass the IDs so the smaller one is always the "buyer" to prevent duplicate rooms)
	var buyerID, sellerID int
	if senderID < req.ReceiverID {
		buyerID, sellerID = senderID, req.ReceiverID
	} else {
		buyerID, sellerID = req.ReceiverID, senderID
	}

	convID, err := s.repo.FindOrCreateConversation(ctx, buyerID, sellerID, req.AuctionID)
	if err != nil {
		return nil, err
	}

	// Create and save the message
	msg := &models.Message{
		ConversationID: convID,
		SenderID:       senderID,
		Content:        req.Content,
	}

	err = s.repo.SaveMessage(ctx, msg)
	if err != nil {
		return nil, err
	}

	// If the receiver is currently online, shoot the message to their phone instantly
	s.hub.SendToUser(req.ReceiverID, map[string]interface{}{
		"type":    "new_message",
		"message": msg,
	})

	return msg, nil
}
