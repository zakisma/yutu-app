package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

type BidRepository struct {
	db *sql.DB
}

func NewBidRepository(db *sql.DB) *BidRepository {
	return &BidRepository{db: db}
}

// getDynamicIncrement calculates the minimum step based on the current price
func getDynamicIncrement(currentPrice float64) float64 {
	if currentPrice < 100 {
		return 5.0
	} else if currentPrice < 500 {
		return 10.0
	} else if currentPrice < 1000 {
		return 20.0
	} else if currentPrice < 5000 {
		return 50.0
	} else if currentPrice < 10000 {
		return 100.0
	}
	return 200.0
}

// PlaceBid securely executes proxy bidding, tiered increments, and anti-sniping.
func (r *BidRepository) PlaceBid(ctx context.Context, auctionID, bidderID int, challengerMaxBid float64) (float64, int, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, 0, err
	}
	defer tx.Rollback()

	var currentPrice, highestMaxBid, startingPrice float64
	var highestBidderID sql.NullInt64 // Handles NULL values safely if no one has bid yet
	var sellerID int
	var status string
	var endTime time.Time

	// lock the row to prevent race conditions
	query := `SELECT current_price, highest_bidder_id, highest_max_bid, starting_price, seller_id, status, end_time FROM auctions WHERE id = $1 FOR UPDATE`
	err = tx.QueryRowContext(ctx, query, auctionID).Scan(
		&currentPrice, &highestBidderID, &highestMaxBid, &startingPrice, &sellerID, &status, &endTime,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return 0, 0, errors.New("auction not found")
		}
		return 0, 0, err
	}

	if status != "ACTIVE" {
		return 0, 0, errors.New("cannot bid on an inactive or sold auction")
	}
	now := time.Now()
	if now.After(endTime) {
		return 0, 0, errors.New("auction has expired")
	}
	if bidderID == sellerID {
		return 0, 0, errors.New("you cannot bid on your own auction")
	}

	//  dynamic increment
	increment := getDynamicIncrement(currentPrice)
	minRequiredBid := currentPrice + increment
	if !highestBidderID.Valid {
		minRequiredBid = startingPrice // the very first bid can just be the starting price
	}

	if challengerMaxBid < minRequiredBid {
		return 0, 0, fmt.Errorf("bid too low. Minimum required bid is %.2f Kč", minRequiredBid)
	}

	// proxy war logic
	newPublicPrice := currentPrice
	newHighestBidderID := bidderID
	newHighestMaxBid := challengerMaxBid

	if !highestBidderID.Valid {
		// Scenario 1: First bidder wins automatically at the starting price
		newPublicPrice = startingPrice
	} else if bidderID == int(highestBidderID.Int64) {
		// Scenario 2: The current leader is increasing their own hidden limit

		if challengerMaxBid <= highestMaxBid {
			return 0, 0, fmt.Errorf("You are already winning with a higher maximum bid of %.2f Kč", highestMaxBid)
		}
		newHighestMaxBid = challengerMaxBid
		newHighestBidderID = int(highestBidderID.Int64)
		newPublicPrice = currentPrice // public price doesn't change
	} else {
		// Scenario 3: A challenger appears against the current leader
		if challengerMaxBid <= highestMaxBid {
			// THE LEADER DEFENDS
			newPublicPrice = challengerMaxBid + getDynamicIncrement(challengerMaxBid)
			if newPublicPrice > highestMaxBid {
				newPublicPrice = highestMaxBid
			}
			newHighestBidderID = int(highestBidderID.Int64)
			newHighestMaxBid = highestMaxBid
		} else {
			// the challenger wins
			newPublicPrice = highestMaxBid + getDynamicIncrement(highestMaxBid)
			if newPublicPrice > challengerMaxBid {
				newPublicPrice = challengerMaxBid
			}
		}
	}

	//  Soft Close, anti-sniping
	extensionThreshold := 3 * time.Minute
	timeRemaining := endTime.Sub(now)
	newEndTime := endTime

	if timeRemaining < extensionThreshold {
		newEndTime = now.Add(extensionThreshold) // extend clock
	}

	//save the new auction state
	updateAuctionQuery := `UPDATE auctions SET current_price = $1, highest_bidder_id = $2, highest_max_bid = $3, end_time = $4 WHERE id = $5`
	_, err = tx.ExecContext(ctx, updateAuctionQuery, newPublicPrice, newHighestBidderID, newHighestMaxBid, newEndTime, auctionID)
	if err != nil {
		return 0, 0, err
	}

	// insert bid history for logging
	insertBidQuery := `INSERT INTO bids (auction_id, bidder_id, amount) VALUES ($1, $2, $3)`
	_, err = tx.ExecContext(ctx, insertBidQuery, auctionID, bidderID, challengerMaxBid)
	if err != nil {
		return 0, 0, err
	}

	err = tx.Commit()
	return newPublicPrice, newHighestBidderID, err
}
