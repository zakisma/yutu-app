package service

import (
	"context"
	"errors"
	"time"

	"github.com/zakisma/yutu-app/internal/models"
	"github.com/zakisma/yutu-app/internal/repository"
)

type AuctionService struct {
	repo *repository.AuctionRepository
}

func NewAuctionService(repo *repository.AuctionRepository) *AuctionService {
	return &AuctionService{repo: repo}
}

func (s *AuctionService) CreateAuction(ctx context.Context, sellerID int, req models.CreateAuctionRequest) (*models.Auction, error) {
	// parse and validate the EndTime
	endTime, err := time.Parse(time.RFC3339, req.EndTime)
	if err != nil {
		return nil, errors.New("invalid date format for end_time")
	}

	if endTime.Before(time.Now()) {
		return nil, errors.New("auction end time must be in the future")
	}

	auction := &models.Auction{
		SellerID:      sellerID,
		Title:         req.Title,
		Description:   req.Description,
		Category:      req.Category,
		StartingPrice: req.StartingPrice,
		CurrentPrice:  req.StartingPrice,
		BuyNowPrice:   req.BuyNowPrice,
		EndTime:       endTime,
		Images:        req.Images,
	}

	err = s.repo.CreateAuction(ctx, auction)
	if err != nil {
		return nil, err
	}

	return auction, nil
}

func (s *AuctionService) GetAllActive(ctx context.Context, limit int, offset int, category string, searchQuery string) ([]*models.Auction, error) {
	return s.repo.GetAllActive(ctx, limit, offset, category, searchQuery)
}

func (s *AuctionService) GetByID(ctx context.Context, id int) (*models.Auction, error) {
	return s.repo.GetByID(ctx, id)
}
func (s *AuctionService) Delete(ctx context.Context, id int, sellerID int) error {
	return s.repo.Delete(ctx, id, sellerID)
}
func (s *AuctionService) GetWatchlist(ctx context.Context, userID int) ([]*models.Auction, error) {
	return s.repo.GetWatchlist(ctx, userID)
}
func (s *AuctionService) ToggleWatchlist(ctx context.Context, userID int, auctionID int) (bool, error) {
	return s.repo.ToggleWatchlist(ctx, userID, auctionID)
}

func (s *AuctionService) GetMyAuctions(ctx context.Context, sellerID int, limit int, offset int) ([]*models.Auction, error) {
	return s.repo.GetMyAuctions(ctx, sellerID, limit, offset)
}

func (s *AuctionService) GetMyBids(ctx context.Context, userID int, limit int, offset int) ([]*models.Auction, error) {
	return s.repo.GetMyBids(ctx, userID, limit, offset)
}
func (s *AuctionService) BuyItNow(ctx context.Context, auctionID int, buyerID int) error {
	return s.repo.BuyItNow(ctx, auctionID, buyerID)
}
