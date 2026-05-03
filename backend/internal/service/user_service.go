package service

import (
	"context"
	"errors"

	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/repository"
	"github.com/zakisma/yutu-app/internal/utils"
	"golang.org/x/crypto/bcrypt"
)

type UserService struct {
	repo *repository.UserRepository
}

func NewUserService(repo *repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) Register(ctx context.Context, req models.UserRegisterRequest) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	user := &models.User{
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		FullName:     req.FullName,
		Role:         "USER",
	}

	err = s.repo.CreateUser(ctx, user)
	if err != nil {
		// return nil, err
		if errors.Is(err, repository.ErrDuplicateEmail) {
			//do not leak existence of a user
			return nil
		}
		return err
	}

	return nil
}

var dummyPasswordHash = []byte("$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy")

func (s *UserService) Login(ctx context.Context, req models.UserLoginRequest) (string, *models.User, error) {
	user, err := s.repo.GetByEmail(ctx, req.Email)
	userExists := err == nil

	// run it comparison so we won't get username enumeration (time based)
	var hashToCompare []byte
	if userExists {
		hashToCompare = []byte(user.PasswordHash)
	} else {
		hashToCompare = dummyPasswordHash
	}
	bcryptErr := bcrypt.CompareHashAndPassword(hashToCompare, []byte(req.Password))

	if !userExists || bcryptErr != nil {
		return "", nil, errors.New("invalid email or password")
	}

	token, err := utils.GenerateJWT(user.ID, user.Role)
	if err != nil {
		return "", nil, err
	}

	return token, user, nil
}

func (s *UserService) UpdateProfile(ctx context.Context, userID int, profileImageURL, phoneNumber, address string) error {
	return s.repo.UpdateProfile(ctx, userID, profileImageURL, phoneNumber, address)
}

func (s *UserService) CreateReview(ctx context.Context, reviewerID int, req models.CreateReviewRequest) (*models.Review, error) {
	if reviewerID == req.RevieweeID {
		return nil, errors.New("you cannot review yourself")
	}

	review := &models.Review{
		ReviewerID:  reviewerID,
		RevieweeID:  req.RevieweeID,
		AuctionID:   req.AuctionID,
		RatingStars: req.RatingStars,
		Comment:     req.Comment,
	}

	err := s.repo.CreateReview(ctx, review)
	if err != nil {
		// if postgres throws a unique constraint error, it means they already reviewed this item
		return nil, errors.New("you have already reviewed this transaction or the data is invalid")
	}

	return review, nil
}

func (s *UserService) GetUserReviews(ctx context.Context, revieweeID int) ([]*models.Review, error) {
	return s.repo.GetUserReviews(ctx, revieweeID)
}

func (s *UserService) GetUserByID(ctx context.Context, id int) (*models.User, error) {
	return s.repo.GetUserByID(ctx, id)
}
