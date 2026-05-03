package router

import (
	"net/http"
	"os"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/zakisma/yutu-app/internal/handlers"
	"github.com/zakisma/yutu-app/internal/ws"

	customAuth "github.com/zakisma/yutu-app/internal/middleware"
)

func getAllowedOrigins() []string {
	raw := os.Getenv("ALLOWED_ORIGINS")
	if raw == "" {
		return []string{
			"http://localhost:3000",
		}
	}
	parts := strings.Split(raw, ",")
	origins := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			origins = append(origins, p)
		}
	}
	return origins
}

// ADDED: wsHub parameter
func SetupRoutes(userHandler *handlers.UserHandler, auctionHandler *handlers.AuctionHandler,
	bidHandler *handlers.BidHandler, orderHandler *handlers.OrderHandler, wsHub *ws.Hub,
	msgHandler *handlers.MessageHandler, stripeWebhookHandler *handlers.StripeWebhookHandler) http.Handler {

	r := chi.NewRouter()
	r.Use(blockSensitivePaths)

	// Global Middleware (all requets)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Use(cors.Handler(cors.Options{
		// AllowedOrigins: []string{"https://*", "http://*"},
		AllowedOrigins:   getAllowedOrigins(),
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		AllowCredentials: true,
		// AllowedOrigins: []string{
		// 	// "https://domain.com",
		// 	"http://localhost:3000",
		// }
	}))

	r.Use(middleware.SetHeader("X-Frame-Options", "DENY"))
	r.Use(middleware.SetHeader("X-Content-Type-Options", "nosniff"))

	//  API Routes Grouping
	r.Route("/api/v1", func(r chi.Router) {

		//health
		r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("API v1 is healthy"))
		})
		// Stripe webhook — no auth (Stripe signs it), no JSON body parsing before signature verification
		r.Post("/webhooks/stripe", stripeWebhookHandler.HandleWebhook)

		// websocket
		r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
			handlers.HandleConnections(wsHub, w, r)
		})

		// ========= public routes ==========

		// auth of user
		r.Route("/users", func(r chi.Router) {
			r.Post("/register", userHandler.Register)
			r.Post("/login", userHandler.Login)
		})

		r.Get("/users/{id}/reviews", userHandler.GetUserReviews)

		// auctions Routes mix
		r.Route("/auctions", func(r chi.Router) {
			// public auction routes
			r.Get("/", auctionHandler.GetAllActive)
			r.Get("/{id}", auctionHandler.GetByID)

			// private auction routes
			r.Group(func(r chi.Router) {
				r.Use(customAuth.AuthMiddleware)

				r.Get("/my", auctionHandler.GetMyAuctions)
				r.Get("/watchlist", auctionHandler.GetWatchlist)
				r.Get("/bidding", auctionHandler.GetMyBids)
				r.Post("/{id}/watchlist", auctionHandler.ToggleWatchlist)
				r.Post("/", auctionHandler.Create)
				r.Post("/{id}/bids", bidHandler.PlaceBid)
				r.Post("/{id}/buy-now", auctionHandler.BuyItNow)
				r.Delete("/{id}", auctionHandler.Delete)
			})
		})

		// PUBLIC messages
		r.Get("/ws/chat", msgHandler.ConnectChatWS)

		// ========= protected routes ==========
		r.Group(func(r chi.Router) {
			r.Use(customAuth.AuthMiddleware)

			r.Put("/users/me", userHandler.UpdateProfile)
			r.Post("/reviews", userHandler.CreateReview)

			// r.Get("/users/me", func(w http.ResponseWriter, r *http.Request) {
			// 	userID := r.Context().Value("user_id").(int)
			// 	utils.JSONResponse(w, http.StatusOK, map[string]interface{}{"your_user_id": userID})
			// })

			r.Get("/users/me", userHandler.GetMe)

			r.Route("/orders", func(r chi.Router) {
				r.Get("/pending", orderHandler.GetMyOrders)
				r.Post("/{id}/payment-intent", orderHandler.CreatePaymentIntent)
				r.Post("/{id}/create-checkout-session", orderHandler.CreateCheckoutSession)
				r.Post("/{id}/checkout", orderHandler.Checkout)
				r.Post("/{id}/cancel-unpaid", orderHandler.CancelUnpaidOrder)
			})

			// PRIVATE messages
			r.Get("/messages/inbox", msgHandler.GetInbox)
			r.Get("/messages/conversations/{id}", msgHandler.GetMessages)
			r.Post("/messages", msgHandler.SendMessage)

		})
	})

	return r

}

// fix this shit, it allows path traversal
func blockSensitivePaths(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		if strings.Contains(r.URL.Path, ".env") ||
			strings.Contains(r.URL.Path, "/.git") ||
			strings.Contains(r.URL.Path, "config") {

			http.NotFound(w, r)
			return
		}

		next.ServeHTTP(w, r)
	})
}
