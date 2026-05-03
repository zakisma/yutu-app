package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/zakisma/yutu-app/internal/db"
	"github.com/zakisma/yutu-app/internal/handlers"
	"github.com/zakisma/yutu-app/internal/repository"
	"github.com/zakisma/yutu-app/internal/router"
	"github.com/zakisma/yutu-app/internal/service"
	"github.com/zakisma/yutu-app/internal/worker"
	"github.com/zakisma/yutu-app/internal/ws"
)

func main() {
	db.Connect()
	defer db.Close()

	// dependency injection
	userRepo := repository.NewUserRepository(db.DB)
	userSvc := service.NewUserService(userRepo)
	userHandler := handlers.NewUserHandler(userSvc)

	auctionRepo := repository.NewAuctionRepository(db.DB)
	auctionSvc := service.NewAuctionService(auctionRepo)
	auctionHandler := handlers.NewAuctionHandler(auctionSvc)

	wsHub := ws.NewHub()
	go wsHub.Run()

	bidRepo := repository.NewBidRepository(db.DB)
	bidSvc := service.NewBidService(bidRepo)
	bidHandler := handlers.NewBidHandler(bidSvc, wsHub)

	auctionCloser := worker.NewAuctionCloser(auctionRepo)

	orderRepo := repository.NewOrderRepository(db.DB)
	orderSvc := service.NewOrderService(orderRepo)
	orderHandler := handlers.NewOrderHandler(orderSvc)
	stripeWebhookHandler := handlers.NewStripeWebhookHandler(orderSvc)

	chatHub := ws.NewChatHub() // Start the Hub
	msgRepo := repository.NewMessageRepository(db.DB)
	msgSvc := service.NewMessageService(msgRepo, chatHub)
	msgHandler := handlers.NewMessageHandler(msgSvc, chatHub)

	bgCtx := context.Background()
	go auctionCloser.Start(bgCtx)

	r := router.SetupRoutes(userHandler, auctionHandler, bidHandler, orderHandler, wsHub, msgHandler, stripeWebhookHandler)

	//server start
	port := ":8080"
	fmt.Printf("Backend server running on port %s...\n", port)
	if err := http.ListenAndServe(port, r); err != nil {
		log.Fatalf("Server crashed: %s\n", err)
	}
}
