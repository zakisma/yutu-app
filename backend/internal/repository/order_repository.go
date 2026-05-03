package repository

import (
	"context"
	"database/sql"
	"errors"

	"github.com/zakisma/yutu-app/internal/models"
)

type OrderRepository struct {
	db *sql.DB
}

func NewOrderRepository(db *sql.DB) *OrderRepository {
	return &OrderRepository{db: db}
}

// GetPendingOrdersByBuyer fetches unpaid won auctions for a user
func (r *OrderRepository) GetPendingOrdersByBuyer(ctx context.Context, userID int) ([]*models.Order, error) {
	query := `
		SELECT o.id, o.auction_id, o.buyer_id, o.final_amount, o.shipping_address, o.payment_method, o.payment_status, o.created_at 
		FROM orders o
		JOIN auctions a ON o.auction_id = a.id
		WHERE (o.buyer_id = $1 OR a.seller_id = $1) AND o.payment_status = 'PENDING'`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []*models.Order
	for rows.Next() {
		var o models.Order
		if err := rows.Scan(&o.ID, &o.AuctionID, &o.BuyerID, &o.FinalAmount, &o.ShippingAddress, &o.PaymentMethod, &o.PaymentStatus, &o.CreatedAt); err != nil {
			return nil, err
		}
		orders = append(orders, &o)
	}
	return orders, nil
}

// CompleteCheckout securely updates the order to PAID
func (r *OrderRepository) CompleteCheckout(ctx context.Context, orderID int, buyerID int, address string, method string) error {
	query := `UPDATE orders 
	          SET shipping_address = $1, payment_method = $2 
	          WHERE id = $3 AND buyer_id = $4 AND payment_status = 'PENDING'`

	result, err := r.db.ExecContext(ctx, query, address, method, orderID, buyerID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return errors.New("order not found, already paid, or you do not have permission")
	}

	return nil
}

func (r *OrderRepository) GetByID(ctx context.Context, id int) (*models.Order, error) {
	query := `SELECT id, auction_id, buyer_id, final_amount, payment_status FROM orders WHERE id = $1`

	var order models.Order
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&order.ID, &order.AuctionID, &order.BuyerID, &order.FinalAmount, &order.PaymentStatus,
	)

	if err != nil {
		return nil, err
	}
	return &order, nil
}

// AttachPaymentIntent stores the Stripe PI id on the order row.
func (r *OrderRepository) AttachPaymentIntent(ctx context.Context, orderID int, piID string) error {
	query := `UPDATE orders SET stripe_payment_intent_id = $1 WHERE id = $2 AND payment_status = 'PENDING'`
	result, err := r.db.ExecContext(ctx, query, piID, orderID)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		return errors.New("order not found or already paid")
	}
	return nil
}

// MarkPaidByPaymentIntent flips the order to PAID. Called only by the webhook.
func (r *OrderRepository) MarkPaidByPaymentIntent(ctx context.Context, piID string) error {
	query := `UPDATE orders 
	          SET payment_status = 'PAID' 
	          WHERE stripe_payment_intent_id = $1 AND payment_status = 'PENDING'`
	result, err := r.db.ExecContext(ctx, query, piID)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		// Either the order is already paid (duplicate webhook — safe to ignore)
		// or the PI ID doesn't match any order (suspicious). Return nil for
		// idempotency: Stripe retries webhooks aggressively.
		return nil
	}
	return nil
}

// MarkOrderPaid flips an order to PAID by its primary key. Called by the
// webhook for the Checkout Session flow
func (r *OrderRepository) MarkOrderPaid(ctx context.Context, orderID int) error {
	query := `UPDATE orders 
	          SET payment_status = 'PAID' 
	          WHERE id = $1 AND payment_status = 'PENDING'`
	result, err := r.db.ExecContext(ctx, query, orderID)
	if err != nil {
		return err
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		// Already paid (duplicate webhook) or doesn't exist — idempotent no-op.
		return nil
	}
	return nil
}

func (r *OrderRepository) CancelUnpaidOrder(ctx context.Context, orderID int, sellerID int) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var auctionID int
	err = tx.QueryRowContext(ctx, `
		UPDATE orders
		SET payment_status = 'CANCELLED_UNPAID'
		WHERE id = $1 AND payment_status = 'PENDING'
		RETURNING auction_id`, orderID).Scan(&auctionID)

	if err != nil {
		return errors.New("objednávku nelze zrušit (není PENDING nebo neexistuje)")
	}

	res, err := tx.ExecContext(ctx, `UPDATE auctions SET status = 'CANCELLED' WHERE id = $1 AND seller_id = $2`, auctionID, sellerID)
	if err != nil {
		return err
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		return errors.New("neautorizováno: nejste prodejce této aukce")
	}

	return tx.Commit()
}
