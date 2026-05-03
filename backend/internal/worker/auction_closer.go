package worker

import (
	"context"
	"log"
	"time"

	"github.com/zakisma/yutu-app/internal/repository"
)

type AuctionCloser struct {
	repo *repository.AuctionRepository
}

func NewAuctionCloser(repo *repository.AuctionRepository) *AuctionCloser {
	return &AuctionCloser{repo: repo}
}

// Start runs the background job. It ticks every 10 seconds.
func (w *AuctionCloser) Start(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("Auction Closer Worker stopped.")
			return
		case <-ticker.C:
			func() {
				defer func() {
					if r := recover(); r != nil {
						log.Printf("CRITICAL: Panic recovered in Auction Closer Worker: %v\n", r)
					}
				}()

				w.processExpiredAuctions(ctx)
			}()
		}
	}
}

func (w *AuctionCloser) processExpiredAuctions(ctx context.Context) {
	// get all expired auctions
	ids, err := w.repo.GetExpiredActiveAuctions(ctx)
	if err != nil {
		log.Printf("Worker Error fetching expired auctions: %v\n", err)
		return
	}

	if len(ids) == 0 {
		return
	}

	// close expired ones one by one
	for _, id := range ids {
		err := w.repo.CloseAuction(ctx, id)
		if err != nil {
			log.Printf("Worker Error closing auction %d: %v\n", id, err)
		} else {
			log.Printf("Worker: Successfully closed auction ID %d\n", id)
		}
	}
}
