package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-playground/validator/v10"
	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/service"
	"github.com/zakisma/yutu-app/internal/utils"

	"strconv"

	"github.com/go-chi/chi/v5"
)

type UserHandler struct {
	svc      *service.UserService
	validate *validator.Validate
}

// NewUserHandler injects the service and initializes the validator
func NewUserHandler(svc *service.UserService) *UserHandler {
	return &UserHandler{
		svc:      svc,
		validate: validator.New(),
	}
}

// Register processes the incoming user registration request
func (h *UserHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req models.UserRegisterRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Failed to register user")
		return
	}

	// user, err := h.svc.Register(r.Context(), req)
	err := h.svc.Register(r.Context(), req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to register user")
		return
	}

	// utils.JSONResponse(w, http.StatusCreated, user)
	utils.JSONResponse(w, http.StatusCreated,
		map[string]string{"message": "If the account can be created, you will receive further instructions."})
}

// Add this method to your UserHandler struct
func (h *UserHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req models.UserLoginRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Validation failed: Email and Password are required")
		return
	}

	token, user, err := h.svc.Login(r.Context(), req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusUnauthorized, err.Error())
		return
	}

	response := struct {
		Token string       `json:"token"`
		User  *models.User `json:"user"`
	}{
		Token: token,
		User:  user,
	}

	utils.JSONResponse(w, http.StatusOK, response)
}

func (h *UserHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	var req models.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid phone number format. Must be international (e.g., +123456789)")
		return
	}

	err := h.svc.UpdateProfile(r.Context(), userID, req.ProfileImageURL, req.PhoneNumber, req.Address)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to update profile")
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"message": "Profile updated successfully"})
}

func (h *UserHandler) CreateReview(w http.ResponseWriter, r *http.Request) {
	reviewerID := r.Context().Value("user_id").(int)

	var req models.CreateReviewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Please provide a star rating (1-5) and a comment")
		return
	}

	review, err := h.svc.CreateReview(r.Context(), reviewerID, req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusCreated, review)
}

func (h *UserHandler) GetUserReviews(w http.ResponseWriter, r *http.Request) {
	userIDStr := chi.URLParam(r, "id")
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid user ID")
		return
	}

	reviews, err := h.svc.GetUserReviews(r.Context(), userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch reviews")
		return
	}

	if reviews == nil {
		reviews = []*models.Review{}
	}

	utils.JSONResponse(w, http.StatusOK, reviews)
}

func (h *UserHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	user, err := h.svc.GetUserByID(r.Context(), userID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusNotFound, "User not found")
		return
	}

	utils.JSONResponse(w, http.StatusOK, user)
}
