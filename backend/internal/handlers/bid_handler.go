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

type BidHandler struct {
	svc      *service.BidService
	validate *validator.Validate
	hub      *ws.Hub
}

func NewBidHandler(svc *service.BidService, hub *ws.Hub) *BidHandler {
	return &BidHandler{
		svc:      svc,
		validate: validator.New(),
		hub:      hub,
	}
}

// PlaceBid handles POST /api/v1/auctions/{id}/bids
func (h *BidHandler) PlaceBid(w http.ResponseWriter, r *http.Request) {
	userIDValue := r.Context().Value("user_id")
	if userIDValue == nil {
		utils.ErrorResponse(w, http.StatusUnauthorized, "User not authenticated")
		return
	}
	bidderID := userIDValue.(int)

	auctionIDStr := chi.URLParam(r, "id")
	auctionID, err := strconv.Atoi(auctionIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid auction ID")
		return
	}

	var req models.PlaceBidRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Validation failed: Please provide a valid amount")
		return
	}

	// execute service: now returns the dynamically calculated public price
	newPublicPrice, newWinnerID, err := h.svc.PlaceBid(r.Context(), auctionID, bidderID, req.Amount)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	// broadcast the new public price via websocket
	wsMessage := map[string]interface{}{
		"auction_id":        auctionID,
		"new_price":         newPublicPrice,
		"bidder_id":         bidderID,
		"highest_bidder_id": newWinnerID,
	}
	messageBytes, _ := json.Marshal(wsMessage)
	h.hub.Broadcast <- messageBytes

	// respond to the user
	utils.JSONResponse(w, http.StatusCreated, map[string]interface{}{
		"message":   "Bid placed successfully",
		"new_price": newPublicPrice,
	})
}
