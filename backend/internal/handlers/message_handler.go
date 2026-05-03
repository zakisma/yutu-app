package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/service"
	"github.com/zakisma/yutu-app/internal/utils"
	"github.com/zakisma/yutu-app/internal/ws"
)

type MessageHandler struct {
	svc      *service.MessageService
	hub      *ws.ChatHub
	validate *validator.Validate
}

func NewMessageHandler(svc *service.MessageService, hub *ws.ChatHub) *MessageHandler {
	return &MessageHandler{
		svc:      svc,
		hub:      hub,
		validate: validator.New(),
	}
}

func (h *MessageHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	var req models.CreateMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Validation failed")
		return
	}

	msg, err := h.svc.SendMessage(r.Context(), userID, req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to send message")
		return
	}

	utils.JSONResponse(w, http.StatusCreated, msg)
}

func (h *MessageHandler) GetInbox(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)
	inbox, err := h.svc.GetInbox(r.Context(), userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch inbox")
		return
	}
	if inbox == nil {
		inbox = []*models.Conversation{}
	}
	utils.JSONResponse(w, http.StatusOK, inbox)
}

// get specific chat history
func (h *MessageHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	convIDStr := chi.URLParam(r, "id")
	convID, _ := strconv.Atoi(convIDStr)

	messages, err := h.svc.GetMessages(r.Context(), convID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch messages")
		return
	}
	if messages == nil {
		messages = []*models.Message{}
	}
	utils.JSONResponse(w, http.StatusOK, messages)
}

func (h *MessageHandler) ConnectChatWS(w http.ResponseWriter, r *http.Request) {
	tokenStr := r.Header.Get("Sec-WebSocket-Protocol")

	userID, _, err := utils.ValidateJWT(tokenStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusUnauthorized, "Invalid or missing WebSocket token")
		return
	}

	upgrader.Subprotocols = []string{tokenStr}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	h.hub.Register(userID, conn)

	// listen until they disconnect, then Unregister
	defer func() {
		h.hub.Unregister(userID)
		conn.Close()
	}()

	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			break // The user closed the app or lost internet connection
		}
	}
}
