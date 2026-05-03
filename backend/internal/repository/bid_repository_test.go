package repository

import (
	"context"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

// TestGetDynamicIncrement verifies the price increments
func TestGetDynamicIncrement(t *testing.T) {
	tests := []struct {
		name         string
		currentPrice float64
		expectedStep float64
	}{
		{"Tier 1: Under 100", 50.0, 5.0},
		{"Tier 2: Exactly 100", 100.0, 10.0},
		{"Tier 2: Under 500", 420.0, 10.0},
		{"Tier 3: Under 1000", 800.0, 20.0},
		{"Tier 4: Under 5000", 2500.0, 50.0},
		{"Tier 5: Under 10000", 7500.0, 100.0},
		{"Tier 6: Over 10000", 15000.0, 200.0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getDynamicIncrement(tt.currentPrice)
			if result != tt.expectedStep {
				t.Errorf("For price %.2f, expected increment %.2f, but got %.2f",
					tt.currentPrice, tt.expectedStep, result)
			}
		})
	}
}

// TestPlaceBid_Scenarios uses sqlmock to verify the three proxy bidding scenarios
func TestPlaceBid_Scenarios(t *testing.T) {
	ctx := context.Background()
	auctionID := 42
	sellerID := 100
	futureTime := time.Now().Add(2 * time.Hour)

	// --- SCENARIO 1: First bid on an empty auction ---
	t.Run("ScenarioA_FirstBid_SetsPublicPriceToStarting", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		bidderID := 200
		challengerMaxBid := 500.0
		startingPrice := 100.0

		mock.ExpectBegin()

		// Expect: SELECT ... FOR UPDATE returns no existing leader
		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(startingPrice, nil, 0.0, startingPrice, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		// Expect: UPDATE with newPublicPrice = startingPrice (100), bidder = 200, maxBid = 500
		mock.ExpectExec("UPDATE auctions").
			WithArgs(startingPrice, bidderID, challengerMaxBid, sqlmock.AnyArg(), auctionID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		// Expect: INSERT into bids
		mock.ExpectExec("INSERT INTO bids").
			WithArgs(auctionID, bidderID, challengerMaxBid).
			WillReturnResult(sqlmock.NewResult(1, 1))

		// Expect: COMMIT
		mock.ExpectCommit()

		// Execute
		newPrice, newBidder, err := repo.PlaceBid(ctx, auctionID, bidderID, challengerMaxBid)
		if err != nil {
			t.Fatalf("expected success, got error: %v", err)
		}
		if newPrice != startingPrice {
			t.Errorf("Scenario A: expected newPrice=%.2f (startingPrice), got %.2f", startingPrice, newPrice)
		}
		if newBidder != bidderID {
			t.Errorf("Scenario A: expected newBidder=%d, got %d", bidderID, newBidder)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("unfulfilled DB expectations: %v", err)
		}
	})

	// --- SCENARIO 2: Current leader raises own max limit ---
	t.Run("ScenarioB_LeaderRaisesMax_PublicPriceUnchanged", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		leaderID := 200
		oldMax := 500.0
		newMax := 1000.0
		currentPrice := 150.0

		mock.ExpectBegin()

		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(currentPrice, leaderID, oldMax, 100.0, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		// Public price should NOT change; only highestMaxBid updates
		mock.ExpectExec("UPDATE auctions").
			WithArgs(currentPrice, leaderID, newMax, sqlmock.AnyArg(), auctionID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec("INSERT INTO bids").
			WithArgs(auctionID, leaderID, newMax).
			WillReturnResult(sqlmock.NewResult(1, 1))

		mock.ExpectCommit()

		newPrice, newBidder, err := repo.PlaceBid(ctx, auctionID, leaderID, newMax)
		if err != nil {
			t.Fatalf("expected success, got error: %v", err)
		}
		if newPrice != currentPrice {
			t.Errorf("Scenario B: expected newPrice=%.2f (unchanged), got %.2f", currentPrice, newPrice)
		}
		if newBidder != leaderID {
			t.Errorf("Scenario B: expected newBidder=%d, got %d", leaderID, newBidder)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("unfulfilled DB expectations: %v", err)
		}
	})

	// --- SCENARIO 3 (rejection): Leader tries to LOWER their max ---
	t.Run("ScenarioB_RejectsLoweringOwnMax", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		leaderID := 200
		existingMax := 1000.0
		attemptedLowerMax := 800.0 // lower than existing

		mock.ExpectBegin()

		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(150.0, leaderID, existingMax, 100.0, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		mock.ExpectRollback()

		_, _, err = repo.PlaceBid(ctx, auctionID, leaderID, attemptedLowerMax)
		if err == nil {
			t.Fatalf("expected rejection error, got nil")
		}
	})

	// --- SCENARIO 3a: Challenger outbids the leader ---
	t.Run("ScenarioC_ChallengerWins_NewPriceCalculated", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		oldLeaderID := 200
		challengerID := 300
		oldMaxBid := 300.0
		challengerMaxBid := 1000.0
		currentPrice := 150.0

		mock.ExpectBegin()

		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(currentPrice, oldLeaderID, oldMaxBid, 100.0, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		// Expected newPublicPrice = MIN(oldMaxBid + increment, challengerMaxBid)
		// oldMaxBid=300, increment at price 300 = 10, so 310. challengerMaxBid=1000.
		// MIN(310, 1000) = 310
		expectedNewPrice := 310.0

		mock.ExpectExec("UPDATE auctions").
			WithArgs(expectedNewPrice, challengerID, challengerMaxBid, sqlmock.AnyArg(), auctionID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		mock.ExpectExec("INSERT INTO bids").
			WithArgs(auctionID, challengerID, challengerMaxBid).
			WillReturnResult(sqlmock.NewResult(1, 1))

		mock.ExpectCommit()

		newPrice, newBidder, err := repo.PlaceBid(ctx, auctionID, challengerID, challengerMaxBid)
		if err != nil {
			t.Fatalf("expected success, got error: %v", err)
		}
		if newPrice != expectedNewPrice {
			t.Errorf("Scenario C: expected newPrice=%.2f, got %.2f", expectedNewPrice, newPrice)
		}
		if newBidder != challengerID {
			t.Errorf("Scenario C: expected newBidder=%d, got %d", challengerID, newBidder)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("unfulfilled DB expectations: %v", err)
		}
	})

	// --- SCENARIO 3b: Challenger bids, but leader's hidden max defends the position ---
	t.Run("ScenarioC2_LeaderDefends_AutoBidsOverChallenger", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		leaderID := 200
		challengerID := 300
		leaderMaxBid := 1000.0
		challengerMaxBid := 500.0 // strictly less than leader's hidden max
		currentPrice := 150.0

		mock.ExpectBegin()

		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(currentPrice, leaderID, leaderMaxBid, 100.0, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		expectedNewPrice := 520.0

		//leader mustremain the winner
		mock.ExpectExec("UPDATE auctions").
			WithArgs(expectedNewPrice, leaderID, leaderMaxBid, sqlmock.AnyArg(), auctionID).
			WillReturnResult(sqlmock.NewResult(0, 1))

		//losing bid should be inserted still into bids
		mock.ExpectExec("INSERT INTO bids").
			WithArgs(auctionID, challengerID, challengerMaxBid).
			WillReturnResult(sqlmock.NewResult(1, 1))

		mock.ExpectCommit()

		newPrice, newBidder, err := repo.PlaceBid(ctx, auctionID, challengerID, challengerMaxBid)
		if err != nil {
			t.Fatalf("expected success, got error: %v", err)
		}
		if newPrice != expectedNewPrice {
			t.Errorf("Scenario C2: expected newPrice=%.2f, got %.2f", expectedNewPrice, newPrice)
		}
		if newBidder != leaderID {
			t.Errorf("Scenario C2: leader should retain position, expected winner=%d, got %d", leaderID, newBidder)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("unfulfilled DB expectations: %v", err)
		}
	})

	// --- Self-bid prevention: seller tries to bid on own auction ---
	t.Run("RejectsSellerBiddingOnOwnAuction", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		if err != nil {
			t.Fatalf("failed to create sqlmock: %v", err)
		}
		defer db.Close()

		repo := NewBidRepository(db)

		mock.ExpectBegin()

		rows := sqlmock.NewRows([]string{
			"current_price", "highest_bidder_id", "highest_max_bid",
			"starting_price", "seller_id", "status", "end_time",
		}).AddRow(150.0, nil, 0.0, 100.0, sellerID, "ACTIVE", futureTime)
		mock.ExpectQuery("SELECT current_price").
			WithArgs(auctionID).
			WillReturnRows(rows)

		mock.ExpectRollback()

		// Bidder ID == seller ID
		_, _, err = repo.PlaceBid(ctx, auctionID, sellerID, 500.0)
		if err == nil {
			t.Fatalf("expected rejection (seller cannot bid on own auction), got nil")
		}
	})
}
