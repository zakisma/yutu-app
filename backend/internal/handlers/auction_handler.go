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
)

type AuctionHandler struct {
	svc      *service.AuctionService
	validate *validator.Validate
}

func NewAuctionHandler(svc *service.AuctionService) *AuctionHandler {
	return &AuctionHandler{
		svc:      svc,
		validate: validator.New(),
	}
}

// it handles the POST request to make a new listing
func (h *AuctionHandler) Create(w http.ResponseWriter, r *http.Request) {
	userIDValue := r.Context().Value("user_id")
	if userIDValue == nil {
		utils.ErrorResponse(w, http.StatusUnauthorized, "User not authenticated")
		return
	}
	sellerID := userIDValue.(int)

	var req models.CreateAuctionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if len(req.Images) == 0 {
		utils.ErrorResponse(w, http.StatusBadRequest, "You must upload at least 1 photo")
		return
	}
	if len(req.Images) > 10 {
		utils.ErrorResponse(w, http.StatusBadRequest, "You cannot upload more than 10 photos")
		return
	}

	if req.BuyNowPrice > 0 && req.BuyNowPrice <= req.StartingPrice {
		utils.ErrorResponse(w, http.StatusBadRequest, "Buy It Now price must be greater than the Starting Price")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Validation failed: Please check your inputs")
		return
	}

	auction, err := h.svc.CreateAuction(r.Context(), sellerID, req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusCreated, auction)
}

// GetAllActive handles the GET request to list products with pagination
func (h *AuctionHandler) GetAllActive(w http.ResponseWriter, r *http.Request) {
	limit, offset := getPaginationParams(r)

	category := r.URL.Query().Get("category")
	searchQuery := r.URL.Query().Get("q")

	auctions, err := h.svc.GetAllActive(r.Context(), limit, offset, category, searchQuery)

	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch auctions")
		return
	}

	if auctions == nil {
		auctions = []*models.Auction{}
	}

	utils.JSONResponse(w, http.StatusOK, auctions)
}

// GetByID handles GET /api/v1/auctions/{id}
func (h *AuctionHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid auction ID")
		return
	}

	auction, err := h.svc.GetByID(r.Context(), id)
	if err != nil {
		utils.ErrorResponse(w, http.StatusNotFound, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusOK, auction)
}

func (h *AuctionHandler) GetMyBids(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	limit, offset := getPaginationParams(r)

	auctions, err := h.svc.GetMyBids(r.Context(), userID, limit, offset)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch your bids")
		return
	}

	if auctions == nil {
		auctions = []*models.Auction{}
	}
	utils.JSONResponse(w, http.StatusOK, auctions)
}

func (h *AuctionHandler) GetMyAuctions(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	limit, offset := getPaginationParams(r)

	auctions, err := h.svc.GetMyAuctions(r.Context(), userID, limit, offset)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch your auctions")
		return
	}

	if auctions == nil {
		auctions = []*models.Auction{}
	}
	utils.JSONResponse(w, http.StatusOK, auctions)
}

func (h *AuctionHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	auctionIDStr := chi.URLParam(r, "id")
	auctionID, err := strconv.Atoi(auctionIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid auction ID")
		return
	}

	err = h.svc.Delete(r.Context(), auctionID, userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusForbidden, "Cannot delete this auction (it may already have bids or you are not the owner)")
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"message": "Auction deleted successfully"})
}
func (h *AuctionHandler) GetWatchlist(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)
	auctions, err := h.svc.GetWatchlist(r.Context(), userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch watchlist")
		return
	}
	if auctions == nil {
		auctions = []*models.Auction{}
	}
	utils.JSONResponse(w, http.StatusOK, auctions)
}

func (h *AuctionHandler) ToggleWatchlist(w http.ResponseWriter, r *http.Request) {
	auctionIDStr := chi.URLParam(r, "id")

	auctionID, err := strconv.Atoi(auctionIDStr)
	if err != nil || auctionID <= 0 {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid auction ID format")
		return
	}

	userID := r.Context().Value("user_id").(int)

	isWatched, err := h.svc.ToggleWatchlist(r.Context(), userID, auctionID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to toggle watchlist")
		return
	}
	utils.JSONResponse(w, http.StatusOK, map[string]bool{"is_watched": isWatched})
}

func getPaginationParams(r *http.Request) (int, int) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit < 1 || limit > 50 {
		limit = 10
	}

	offset := (page - 1) * limit
	return limit, offset
}

func (h *AuctionHandler) BuyItNow(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	auctionIDStr := chi.URLParam(r, "id")
	auctionID, err := strconv.Atoi(auctionIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid auction ID")
		return
	}

	err = h.svc.BuyItNow(r.Context(), auctionID, userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"message": "Item purchased successfully! Pending payment."})
}
