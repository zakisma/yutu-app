package handlers

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/webhook"
	"github.com/zakisma/yutu-app/internal/service"
	"github.com/zakisma/yutu-app/internal/utils"
)

type StripeWebhookHandler struct {
	svc *service.OrderService
}

func NewStripeWebhookHandler(svc *service.OrderService) *StripeWebhookHandler {
	return &StripeWebhookHandler{svc: svc}
}

// HandleWebhook verifies the Stripe signature and processes payment events.
func (h *StripeWebhookHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {

	const maxBody = 65536
	payload, err := io.ReadAll(io.LimitReader(r.Body, maxBody))
	if err != nil {
		utils.ErrorResponse(w, http.StatusBadRequest, "Could not read request body")
		return
	}

	endpointSecret := strings.TrimSpace(os.Getenv("STRIPE_WEBHOOK_SECRET"))
	if endpointSecret == "" {
		utils.ErrorResponse(w, http.StatusInternalServerError, "Webhook secret not configured")
		return
	}

	signatureHeader := r.Header.Get("Stripe-Signature")
	event, err := webhook.ConstructEventWithOptions(payload, signatureHeader, endpointSecret, webhook.ConstructEventOptions{
		IgnoreAPIVersionMismatch: true,
	})

	if err != nil {
		log.Println("=== WEBHOOK SIGNATURE FAILED ===")
		// log.Printf("Secret in memory : '%s'\n", endpointSecret)
		// log.Printf("Payload size     : %d bytes\n", len(payload))
		log.Printf("Stripe Error     : %v\n", err)

		utils.ErrorResponse(w, http.StatusBadRequest, "Invalid webhook signature")
		return
	}

	switch event.Type {
	case "payment_intent.succeeded":
		// Fired by the PaymentIntent flow (mobile native PaymentSheet).
		var pi stripe.PaymentIntent
		if err := json.Unmarshal(event.Data.Raw, &pi); err != nil {
			utils.ErrorResponse(w, http.StatusBadRequest, "Invalid payload")
			return
		}

		if err := h.svc.MarkPaidByPaymentIntent(r.Context(), pi.ID); err != nil {
			utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to mark order paid")
			return
		}

	case "checkout.session.completed":
		// Fired by the Checkout Session flow (web). The order ID is carried
		// by ClientReferenceID, which we set when creating the session.
		var session stripe.CheckoutSession
		if err := json.Unmarshal(event.Data.Raw, &session); err != nil {
			utils.ErrorResponse(w, http.StatusBadRequest, "Invalid payload")
			return
		}

		if session.ClientReferenceID == "" {
			log.Printf("checkout.session.completed received without ClientReferenceID (session ID: %s)", session.ID)
			break
		}

		orderID, err := strconv.Atoi(session.ClientReferenceID)
		if err != nil {
			log.Printf("checkout.session.completed has non-numeric ClientReferenceID: %q", session.ClientReferenceID)
			break
		}

		if err := h.svc.MarkOrderPaid(r.Context(), orderID); err != nil {
			utils.ErrorResponse(w, http.StatusInternalServerError, "Failed to mark order paid")
			return
		}

	default:
		// ignore unhandled event types
	}

	w.WriteHeader(http.StatusOK)
}
