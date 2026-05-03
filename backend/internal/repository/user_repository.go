package repository

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/zakisma/yutu-app/internal/models"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

var ErrDuplicateEmail = errors.New("duplicate email")

func (r *UserRepository) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, password_hash, full_name, role)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at`

	err := r.db.QueryRowContext(ctx, query,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.Role,
	).Scan(&user.ID, &user.CreatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "23505") {
			return ErrDuplicateEmail
		}
		return err
	}

	return nil
}

// GetByEmail vyhledá uživatele podle emailu (pro login a validaci unikátnosti)
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	// FIX: Added COALESCE to safely fetch the new profile columns!
	query := `SELECT id, email, password_hash, full_name, role, is_verified, 
			COALESCE(profile_image_url, ''), COALESCE(phone_number, ''), COALESCE(address, ''),
			created_at FROM users WHERE email = $1`

	user := &models.User{}
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FullName, &user.Role, &user.IsVerified,
		&user.ProfileImageURL, &user.PhoneNumber, &user.Address, // <-- MUST BE HERE
		&user.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetUserByID fetches a user by their primary key ID (used for silent profile syncing)
func (r *UserRepository) GetUserByID(ctx context.Context, id int) (*models.User, error) {
	query := `SELECT id, email, password_hash, full_name, role, is_verified, 
			COALESCE(profile_image_url, ''), COALESCE(phone_number, ''), COALESCE(address, ''),
			created_at FROM users WHERE id = $1`

	user := &models.User{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FullName, &user.Role, &user.IsVerified,
		&user.ProfileImageURL, &user.PhoneNumber, &user.Address,
		&user.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) UpdateProfile(ctx context.Context, userID int, profileImageURL, phoneNumber, address string) error {
	query := `
		UPDATE users 
		SET profile_image_url = $1, phone_number = $2, address = $3 
		WHERE id = $4`

	_, err := r.db.ExecContext(ctx, query, profileImageURL, phoneNumber, address, userID)
	return err
}

func (r *UserRepository) CreateReview(ctx context.Context, review *models.Review) error {
	var isValid bool

	checkQuery := `
		SELECT EXISTS (
			SELECT 1 FROM orders o
			JOIN auctions a ON a.id = o.auction_id
			WHERE o.auction_id = $1 
			  AND (
			      -- Scénář A: Zaplaceno (mohou se hodnotit navzájem)
			      (o.payment_status = 'PAID' AND ((o.buyer_id = $2 AND a.seller_id = $3) OR (a.seller_id = $2 AND o.buyer_id = $3)))
			      OR 
			      -- Scénář B: Zrušeno pro nezaplacení (hodnotit smí POUZE prodejce kupujícího)
			      (o.payment_status = 'CANCELLED_UNPAID' AND a.seller_id = $2 AND o.buyer_id = $3)
			  )
		)
	`

	err := r.db.QueryRowContext(ctx, checkQuery, review.AuctionID, review.ReviewerID, review.RevieweeID).Scan(&isValid)
	if err != nil {
		return err
	}
	if !isValid {
		return errors.New("You can leave a review after the payment")
	}

	// 2. Proceed with the insert...
	query := `
		INSERT INTO reviews (reviewer_id, reviewee_id, auction_id, rating_stars, comment)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at`

	return r.db.QueryRowContext(ctx, query,
		review.ReviewerID, review.RevieweeID, review.AuctionID, review.RatingStars, review.Comment,
	).Scan(&review.ID, &review.CreatedAt)
}

// GetUserReviews fetches all reviews written ABOUT a specific user, including the reviewer's details
func (r *UserRepository) GetUserReviews(ctx context.Context, revieweeID int) ([]*models.Review, error) {
	query := `
		SELECT r.id, r.reviewer_id, r.reviewee_id, r.auction_id, r.rating_stars, r.comment, r.created_at,
		       u.full_name, COALESCE(u.profile_image_url, '')
		FROM reviews r
		JOIN users u ON r.reviewer_id = u.id
		WHERE r.reviewee_id = $1
		ORDER BY r.created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, revieweeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reviews []*models.Review
	for rows.Next() {
		var rev models.Review
		err := rows.Scan(
			&rev.ID, &rev.ReviewerID, &rev.RevieweeID, &rev.AuctionID,
			&rev.RatingStars, &rev.Comment, &rev.CreatedAt,
			&rev.ReviewerName, &rev.ReviewerImage,
		)
		if err != nil {
			return nil, err
		}
		reviews = append(reviews, &rev)
	}
	return reviews, nil
}
