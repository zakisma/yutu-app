package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/zakisma/yutu-app/internal/models"
)

type AuctionRepository struct {
	db *sql.DB
}

func NewAuctionRepository(db *sql.DB) *AuctionRepository {
	return &AuctionRepository{db: db}
}

// CreateAuction uses an SQL Transaction to save the auction and its images safely.
func (r *AuctionRepository) CreateAuction(ctx context.Context, auction *models.Auction) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	query := `
		INSERT INTO auctions (seller_id, title, description, category, starting_price, current_price, end_time, status, buy_now_price)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE', $8)
		RETURNING id, start_time`

	err = tx.QueryRowContext(ctx, query,
		auction.SellerID,
		auction.Title,
		auction.Description,
		auction.Category,
		auction.StartingPrice,
		auction.StartingPrice,
		auction.EndTime,
		auction.BuyNowPrice,
	).Scan(&auction.ID, &auction.StartTime)

	if err != nil {
		return err
	}

	// insert selected images
	if len(auction.Images) > 0 {
		imageQuery := `INSERT INTO auction_images (auction_id, image_url, is_primary) VALUES ($1, $2, $3)`

		//to save all photos
		for i, imgURL := range auction.Images {
			isPrimary := false
			if i == 0 {
				isPrimary = true // Make the first image the primary one
			}
			_, err = tx.ExecContext(ctx, imageQuery, auction.ID, imgURL, isPrimary)
			if err != nil {
				return errors.New("failed to save images: " + err.Error())
			}
		}
	}

	return tx.Commit()
}

// GetAllActive fetches all active auctions with dynamic filtering and pagination
func (r *AuctionRepository) GetAllActive(ctx context.Context, limit int, offset int, category string, searchQuery string) ([]*models.Auction, error) {
	query := `
		SELECT a.id, a.seller_id, a.title, a.description, a.category, 
		       a.starting_price, a.current_price, a.buy_now_price, a.start_time, a.end_time, a.status,
		       COALESCE(i.image_url, '') as primary_image
		FROM auctions a
		LEFT JOIN auction_images i ON a.id = i.auction_id AND i.is_primary = true
		WHERE a.status = 'ACTIVE'`

	// dynamic's argumentes
	args := []interface{}{}
	argIndex := 1

	if category != "" && category != "All" {
		query += fmt.Sprintf(" AND a.category = $%d", argIndex)
		args = append(args, category)
		argIndex++
	}

	// filter by search
	if searchQuery != "" {
		query += fmt.Sprintf(" AND (a.title ILIKE $%d OR a.description ILIKE $%d)", argIndex, argIndex)
		args = append(args, "%"+searchQuery+"%")
		argIndex++
	}

	// pagination (always appended last)
	query += fmt.Sprintf(" ORDER BY a.start_time DESC LIMIT $%d OFFSET $%d", argIndex, argIndex+1)
	args = append(args, limit, offset)

	// уxecute йuery using the spread operator (args...)
	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var auctions []*models.Auction
	for rows.Next() {
		var auction models.Auction
		var primaryImage string

		err := rows.Scan(
			&auction.ID, &auction.SellerID, &auction.Title, &auction.Description,
			&auction.Category, &auction.StartingPrice, &auction.CurrentPrice, &auction.BuyNowPrice,
			&auction.StartTime, &auction.EndTime, &auction.Status, &primaryImage,
		)
		if err != nil {
			return nil, err
		}

		if primaryImage != "" {
			auction.Images = []string{primaryImage}
		}
		auctions = append(auctions, &auction)
	}
	return auctions, nil
}

// GetExpiredActiveAuctions finds all auctions that have passed their end_time but are still ACTIVE
func (r *AuctionRepository) GetExpiredActiveAuctions(ctx context.Context) ([]int, error) {
	query := `SELECT id FROM auctions WHERE status = 'ACTIVE' AND end_time <= NOW()`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// CloseAuction processes the end of an auction securely.
func (r *AuctionRepository) CloseAuction(ctx context.Context, auctionID int) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// find the highest bid
	var winnerID int
	var highestBid float64

	bidQuery := `SELECT bidder_id, amount FROM bids WHERE auction_id = $1 ORDER BY amount DESC LIMIT 1`
	err = tx.QueryRowContext(ctx, bidQuery, auctionID).Scan(&winnerID, &highestBid)

	if err != nil {
		if err == sql.ErrNoRows {
			// No bids were placed. Mark as EXPIRED.
			_, err = tx.ExecContext(ctx, `UPDATE auctions SET status = 'EXPIRED' WHERE id = $1`, auctionID)
			if err != nil {
				return err
			}
			return tx.Commit()
		}
		return err // Some other database error
	}

	// bids exist, mark as SOLD.
	_, err = tx.ExecContext(ctx, `UPDATE auctions SET status = 'SOLD' WHERE id = $1`, auctionID)
	if err != nil {
		return err
	}

	// create the Pending Order for the winner
	orderQuery := `
		INSERT INTO orders (auction_id, buyer_id, final_amount, shipping_address, payment_method, payment_status) 
		VALUES ($1, $2, $3, '', '', 'PENDING')`
	_, err = tx.ExecContext(ctx, orderQuery, auctionID, winnerID, highestBid)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// GetByID fetches a single auction and its primary image
func (r *AuctionRepository) GetByID(ctx context.Context, id int) (*models.Auction, error) {
	query := `
		SELECT a.id, a.seller_id, a.title, a.description, a.category, a.starting_price, 
		       a.current_price, a.buy_now_price, a.start_time, a.end_time, a.status, a.highest_bidder_id, u.full_name
		FROM auctions a
		JOIN users u ON a.seller_id = u.id
		WHERE a.id = $1`

	var auction models.Auction

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&auction.ID, &auction.SellerID, &auction.Title, &auction.Description,
		&auction.Category, &auction.StartingPrice, &auction.CurrentPrice, &auction.BuyNowPrice,
		&auction.StartTime, &auction.EndTime, &auction.Status, &auction.HighestBidderID, &auction.SellerName,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("Auction was not found")
		}
		return nil, err
	}

	//  get all photos
	imagesQuery := `SELECT image_url FROM auction_images WHERE auction_id = $1 ORDER BY is_primary DESC, id ASC`
	rows, err := r.db.QueryContext(ctx, imagesQuery, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var url string
		if err := rows.Scan(&url); err == nil {
			auction.Images = append(auction.Images, url)
		}
	}

	return &auction, nil
}

func (r *AuctionRepository) Delete(ctx context.Context, id int, sellerID int) error {
	query := `DELETE FROM auctions WHERE id = $1 AND seller_id = $2`

	result, err := r.db.ExecContext(ctx, query, id, sellerID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return errors.New("auction not found or you do not have permission to delete it")
	}

	return nil
}

// GetWatchlist fetches all auctions saved by the user
func (r *AuctionRepository) GetWatchlist(ctx context.Context, userID int) ([]*models.Auction, error) {
	query := `
		SELECT a.id, a.seller_id, a.title, a.description, a.category, 
		       a.starting_price, a.current_price, a.start_time, a.end_time, a.status,
		       COALESCE(i.image_url, '') as primary_image
		FROM auctions a
		JOIN watchlist w ON a.id = w.auction_id
		LEFT JOIN auction_images i ON a.id = i.auction_id AND i.is_primary = true
		WHERE w.user_id = $1
		ORDER BY w.created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var auctions []*models.Auction
	for rows.Next() {
		var auction models.Auction
		var primaryImage string
		err := rows.Scan(&auction.ID, &auction.SellerID, &auction.Title, &auction.Description, &auction.Category, &auction.StartingPrice, &auction.CurrentPrice, &auction.StartTime, &auction.EndTime, &auction.Status, &primaryImage)
		if err != nil {
			return nil, err
		}
		if primaryImage != "" {
			auction.Images = []string{primaryImage}
		}
		auctions = append(auctions, &auction)
	}
	return auctions, nil
}

// ToggleWatchlist adds or removes an auction from the watchlist. Returns true if added, false if removed.
func (r *AuctionRepository) ToggleWatchlist(ctx context.Context, userID int, auctionID int) (bool, error) {
	var exists bool
	err := r.db.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM watchlist WHERE user_id=$1 AND auction_id=$2)", userID, auctionID).Scan(&exists)
	if err != nil {
		return false, err
	}

	if exists {
		_, err = r.db.ExecContext(ctx, "DELETE FROM watchlist WHERE user_id=$1 AND auction_id=$2", userID, auctionID)
		return false, err // Removed
	} else {
		_, err = r.db.ExecContext(ctx, "INSERT INTO watchlist (user_id, auction_id) VALUES ($1, $2)", userID, auctionID)
		return true, err // Added
	}
}

// GetMyAuctions fetches a paginated list of auctions created by the seller
func (r *AuctionRepository) GetMyAuctions(ctx context.Context, sellerID int, limit int, offset int) ([]*models.Auction, error) {
	query := `
		SELECT a.id, a.seller_id, a.title, a.description, a.category, 
		       a.starting_price, a.current_price, a.buy_now_price, a.start_time, a.end_time, a.status,
		       COALESCE(i.image_url, '') as primary_image
		FROM auctions a
		LEFT JOIN auction_images i ON a.id = i.auction_id AND i.is_primary = true
		WHERE a.seller_id = $1`

	// Using the Query Builder pattern for consistency
	args := []interface{}{sellerID}
	argIndex := 2

	query += fmt.Sprintf(" ORDER BY a.start_time DESC LIMIT $%d OFFSET $%d", argIndex, argIndex+1)
	args = append(args, limit, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var auctions []*models.Auction
	for rows.Next() {
		var auction models.Auction
		var primaryImage string
		err := rows.Scan(
			&auction.ID, &auction.SellerID, &auction.Title, &auction.Description,
			&auction.Category, &auction.StartingPrice, &auction.CurrentPrice, &auction.BuyNowPrice,
			&auction.StartTime, &auction.EndTime, &auction.Status, &primaryImage,
		)
		if err != nil {
			return nil, err
		}
		if primaryImage != "" {
			auction.Images = []string{primaryImage}
		}
		auctions = append(auctions, &auction)
	}
	return auctions, nil
}

// GetMyBids fetches a paginated list of all auctions where the user placed a bid
func (r *AuctionRepository) GetMyBids(ctx context.Context, userID int, limit int, offset int) ([]*models.Auction, error) {
	query := `
		SELECT DISTINCT a.id, a.seller_id, a.title, a.description, a.category, 
		       a.starting_price, a.current_price, a.buy_now_price, a.start_time, a.end_time, a.status,
		       COALESCE(i.image_url, '') as primary_image
		FROM auctions a
		JOIN bids b ON a.id = b.auction_id
		LEFT JOIN auction_images i ON a.id = i.auction_id AND i.is_primary = true
		WHERE b.bidder_id = $1`

	args := []interface{}{userID}
	argIndex := 2

	query += fmt.Sprintf(" ORDER BY a.end_time DESC LIMIT $%d OFFSET $%d", argIndex, argIndex+1)
	args = append(args, limit, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var auctions []*models.Auction
	for rows.Next() {
		var auction models.Auction
		var primaryImage string
		err := rows.Scan(
			&auction.ID, &auction.SellerID, &auction.Title, &auction.Description,
			&auction.Category, &auction.StartingPrice, &auction.CurrentPrice, &auction.BuyNowPrice,
			&auction.StartTime, &auction.EndTime, &auction.Status, &primaryImage,
		)
		if err != nil {
			return nil, err
		}
		if primaryImage != "" {
			auction.Images = []string{primaryImage}
		}
		auctions = append(auctions, &auction)
	}
	return auctions, nil
}

func (r *AuctionRepository) UpdateAuctionPriceAndWinner(ctx context.Context, auctionID int, newPrice float64, winnerID int, maxBid float64) error {
	query := `
		UPDATE auctions 
		SET current_price = $1, highest_bidder_id = $2, highest_max_bid = $3 
		WHERE id = $4`
	_, err := r.db.ExecContext(ctx, query, newPrice, winnerID, maxBid, auctionID)
	return err
}

// BuyItNow instantly purchases an auction if it's active.
func (r *AuctionRepository) BuyItNow(ctx context.Context, auctionID int, buyerID int) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// We grab the highest_bidder_id at the exact same time we check the status.
	// The "FOR UPDATE" locks the row, preventing anyone else from bidding at this exact millisecond.
	var status string
	var buyNowPrice float64
	var sellerID int
	var highestBidderID *int // can be NULL in the database

	err = tx.QueryRowContext(ctx, `SELECT status, buy_now_price, seller_id, highest_bidder_id FROM auctions WHERE id = $1 FOR UPDATE`, auctionID).Scan(&status, &buyNowPrice, &sellerID, &highestBidderID)
	if err != nil {
		return errors.New("auction not found")
	}

	if status != "ACTIVE" {
		return errors.New("this auction is no longer active")
	}
	if buyNowPrice <= 0 {
		return errors.New("this auction does not have a buy it now option")
	}
	if sellerID == buyerID {
		return errors.New("you cannot buy your own auction")
	}

	if highestBidderID != nil {
		return errors.New("buy it now is no longer available because bidding has started")
	}

	_, err = tx.ExecContext(ctx, `UPDATE auctions SET status = 'SOLD', current_price = $1, highest_bidder_id = $2 WHERE id = $3`, buyNowPrice, buyerID, auctionID)
	if err != nil {
		return err
	}

	//  INSERT A BID SO IT SHOWS UP IN THE ACTIVITY FEED
	insertBidQuery := `INSERT INTO bids (auction_id, bidder_id, amount) VALUES ($1, $2, $3)`
	_, err = tx.ExecContext(ctx, insertBidQuery, auctionID, buyerID, buyNowPrice)
	if err != nil {
		return err
	}

	//  Create the Pending Order
	orderQuery := `
		INSERT INTO orders (auction_id, buyer_id, final_amount, shipping_address, payment_method, payment_status) 
		VALUES ($1, $2, $3, '', '', 'PENDING')`
	_, err = tx.ExecContext(ctx, orderQuery, auctionID, buyerID, buyNowPrice)
	if err != nil {
		return err
	}

	return tx.Commit()
}
