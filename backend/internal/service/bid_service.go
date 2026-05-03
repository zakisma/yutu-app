package service

import (
	"context"

	"github.com/zakisma/yutu-app/internal/repository"
)

type BidService struct {
	repo *repository.BidRepository
}

func NewBidService(repo *repository.BidRepository) *BidService {
	return &BidService{repo: repo}
}

// it passes the bid to the repository where the DB is safely locked for the proxymath
func (s *BidService) PlaceBid(ctx context.Context, auctionID, bidderID int, amount float64) (float64, int, error) {
	return s.repo.PlaceBid(ctx, auctionID, bidderID, amount)
}
