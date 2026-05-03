package handlers

import (
	"os"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/paymentintent"

	"encoding/json"
	"net/http"

	"github.com/go-playground/validator/v10"
	"github.com/stripe/stripe-go/v76/checkout/session"
	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/service"
	"github.com/zakisma/yutu-app/internal/utils"
)

type OrderHandler struct {
	svc      *service.OrderService
	validate *validator.Validate
}

func NewOrderHandler(svc *service.OrderService) *OrderHandler {
	return &OrderHandler{
		svc:      svc,
		validate: validator.New(),
	}
}

// GetMyOrders handles GET /api/v1/orders/pending
func (h *OrderHandler) GetMyOrders(w http.ResponseWriter, r *http.Request) {
	buyerID := r.Context().Value("user_id").(int)

	orders, err := h.svc.GetMyPendingOrders(r.Context(), buyerID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to fetch orders")
		return
	}

	if orders == nil {
		orders = []*models.Order{}
	}

	utils.JSONResponse(w, http.StatusOK, orders)
}

// Checkout handles POST /api/v1/orders/{id}/checkout
func (h *OrderHandler) Checkout(w http.ResponseWriter, r *http.Request) {
	buyerID := r.Context().Value("user_id").(int)

	orderIDStr := chi.URLParam(r, "id")
	orderID, err := strconv.Atoi(orderIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	var req models.CheckoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := h.validate.Struct(req); err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Validation failed: address and payment method are required")
		return
	}

	err = h.svc.ProcessCheckout(r.Context(), orderID, buyerID, req)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"message": "Payment successful and order completed!"})
}

// CreatePaymentIntent connects to Stripe and generates a checkout session
func (h *OrderHandler) CreatePaymentIntent(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	orderIDStr := chi.URLParam(r, "id")
	orderID, err := strconv.Atoi(orderIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	order, err := h.svc.GetByID(r.Context(), orderID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusNotFound, "Order not found")
		return
	}

	if order.BuyerID != userID {
		utils.ErrorResponse(w, http.StatusForbidden, "You do not own this order")
		return
	}
	if order.PaymentStatus == "PAID" {
		utils.ErrorResponse(w, http.StatusBadRequest, "This order is already paid")
		return
	}

	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	// calculate Amount in Cents
	amountInCents := int64(order.FinalAmount * 100)

	// create the PaymentIntent
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(amountInCents),
		Currency: stripe.String(string(stripe.CurrencyCZK)),
		AutomaticPaymentMethods: &stripe.PaymentIntentAutomaticPaymentMethodsParams{
			Enabled: stripe.Bool(true),
		},
	}

	// Attach our order ID to the PaymentIntent's metadata so the webhook
	// knows which order to mark as PAID.
	params.Metadata = map[string]string{
		"order_id": strconv.Itoa(orderID),
	}

	pi, err := paymentintent.New(params)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to initialize payment")
		return
	}

	// Persist the PaymentIntent ID on the order so we can reconcile later
	if err := h.svc.AttachPaymentIntent(r.Context(), orderID, pi.ID); err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to attach payment intent")
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{
		"client_secret": pi.ClientSecret,
	})
}

// CreateCheckoutSession generates a URL for Stripe's hosted web checkout
func (h *OrderHandler) CreateCheckoutSession(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)
	orderIDStr := chi.URLParam(r, "id")
	orderID, _ := strconv.Atoi(orderIDStr)

	order, err := h.svc.GetByID(r.Context(), orderID)
	if err != nil || order.BuyerID != userID || order.PaymentStatus == "PAID" {
		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid or paid order")
		return
	}

	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	amountInCents := int64(order.FinalAmount * 100)

	params := &stripe.CheckoutSessionParams{
		PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency: stripe.String(string(stripe.CurrencyCZK)),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name: stripe.String("Yutu Auction Win"),
					},
					UnitAmount: stripe.Int64(amountInCents),
				},
				Quantity: stripe.Int64(1),
			},
		},

		Mode: stripe.String(string(stripe.CheckoutSessionModePayment)),

		ClientReferenceID: stripe.String(strconv.Itoa(orderID)),

		SuccessURL: stripe.String("http://localhost:3000/"),
		CancelURL:  stripe.String("http://localhost:3000/"),
	}

	s, err := session.New(params)
	if err != nil {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to create session")
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"url": s.URL})
}

func (h *OrderHandler) CancelUnpaidOrder(w http.ResponseWriter, r *http.Request) {
	sellerID := r.Context().Value("user_id").(int)

	orderIDStr := chi.URLParam(r, "id")
	orderID, err := strconv.Atoi(orderIDStr)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Neplatné ID objednávky")
		return
	}

	err = h.svc.CancelUnpaidOrder(r.Context(), orderID, sellerID)
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(w, http.StatusOK, map[string]string{"message": "Objednávka byla zrušena pro nezaplacení"})
}
