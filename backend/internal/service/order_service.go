package service

import (
	"context"

	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/repository"
)

type OrderService struct {
	repo *repository.OrderRepository
}

func NewOrderService(repo *repository.OrderRepository) *OrderService {
	return &OrderService{repo: repo}
}

func (s *OrderService) GetMyPendingOrders(ctx context.Context, buyerID int) ([]*models.Order, error) {
	return s.repo.GetPendingOrdersByBuyer(ctx, buyerID)
}

func (s *OrderService) ProcessCheckout(ctx context.Context, orderID int, buyerID int, req models.CheckoutRequest) error {
	// In a real production app, this is the place where we need to verify the Stripe Webhook token.
	// this is temp solution for the thesis
	return s.repo.CompleteCheckout(ctx, orderID, buyerID, req.ShippingAddress, req.PaymentMethod)
}
func (s *OrderService) GetByID(ctx context.Context, id int) (*models.Order, error) {
	return s.repo.GetByID(ctx, id)
}

// AttachPaymentIntent links a Stripe PaymentIntent ID to an order row.
func (s *OrderService) AttachPaymentIntent(ctx context.Context, orderID int, piID string) error {
	return s.repo.AttachPaymentIntent(ctx, orderID, piID)
}

// MarkPaidByPaymentIntent is called by the Stripe webhook after
// payment_intent.succeeded. It flips the order to PAID.
func (s *OrderService) MarkPaidByPaymentIntent(ctx context.Context, piID string) error {
	return s.repo.MarkPaidByPaymentIntent(ctx, piID)
}

func (s *OrderService) MarkOrderPaid(ctx context.Context, orderID int) error {
	return s.repo.MarkOrderPaid(ctx, orderID)
}

func (s *OrderService) CancelUnpaidOrder(ctx context.Context, orderID int, sellerID int) error {
	return s.repo.CancelUnpaidOrder(ctx, orderID, sellerID)
}
