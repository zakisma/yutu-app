package models

import (
	"time"
)

type Auction struct {
	ID              int       `json:"id"`
	SellerID        int       `json:"seller_id"`
	SellerName      string    `json:"seller_name"`
	Title           string    `json:"title"`
	Description     string    `json:"description"`
	Category        string    `json:"category"`
	StartingPrice   float64   `json:"starting_price"`
	CurrentPrice    float64   `json:"current_price"`
	StartTime       time.Time `json:"start_time"`
	EndTime         time.Time `json:"end_time"`
	Status          string    `json:"status"`           // 'ACTIVE', 'SOLD', 'EXPIRED'
	Images          []string  `json:"images,omitempty"` //this will be filled from the images table
	BuyNowPrice     float64   `json:"buy_now_price"`
	HighestBidderID *int      `json:"highest_bidder_id,omitempty"` // pointer because it can be NULL initially
	HighestMaxBid   float64   `json:"-"`                           // hidden,do nobody can see max limit
}

// AuctionImage represents a single photo of an item.
type AuctionImage struct {
	ID        int    `json:"id"`
	AuctionID int    `json:"auction_id"`
	ImageURL  string `json:"image_url"`
	IsPrimary bool   `json:"is_primary"`
}

// Bid represents an offer made by a user.
type Bid struct {
	ID        int       `json:"id"`
	AuctionID int       `json:"auction_id"`
	BidderID  int       `json:"bidder_id"`
	Amount    float64   `json:"amount"`
	BidTime   time.Time `json:"bid_time"`
}

type CreateAuctionRequest struct {
	Title         string   `json:"title" validate:"required,max=255"`
	Description   string   `json:"description" validate:"required,max=10000"`
	Category      string   `json:"category" validate:"required,max=50"`
	StartingPrice float64  `json:"starting_price" validate:"required,gt=0,lte=9999999"`
	EndTime       string   `json:"end_time" validate:"required"`
	Images        []string `json:"images" validate:"required,min=1,max=10,dive,url,max=500"`
	BuyNowPrice   float64  `json:"buy_now_price" validate:"gte=0,lte=9999999"`
}

// defines what the frontend sends to place a bid
type PlaceBidRequest struct {
	Amount float64 `json:"amount" validate:"required,gt=0,lte=9999999"`
}

// Order represents the final purchase state after an auction is won
type Order struct {
	ID                    int       `json:"id"`
	AuctionID             int       `json:"auction_id"`
	BuyerID               int       `json:"buyer_id"`
	FinalAmount           float64   `json:"final_amount"`
	ShippingAddress       string    `json:"shipping_address"`
	PaymentMethod         string    `json:"payment_method"`
	PaymentStatus         string    `json:"payment_status"` // 'PENDING' or 'PAID'
	StripePaymentIntentID string    `json:"-"`
	CreatedAt             time.Time `json:"created_at"`
}

type CheckoutRequest struct {
	ShippingAddress string `json:"shipping_address" validate:"required, max=10000"`
	PaymentMethod   string `json:"payment_method" validate:"required, max=50"` // e.g., "STRIPE_TEST", "ESCROW" in the future
}
