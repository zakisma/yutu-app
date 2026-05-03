package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/zakisma/yutu-app/internal/utils"
)

// AuthMiddleware ensures the user is logged in with a valid JWT
func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			utils.ErrorResponse(w, http.StatusUnauthorized, "Missing Authorization header")
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" || parts[1] == "" {
			utils.ErrorResponse(w, http.StatusUnauthorized, "Invalid Authorization header format")
			return
		}

		userID, role, err := utils.ValidateJWT(parts[1])
		if err != nil {
			utils.ErrorResponse(w, http.StatusUnauthorized, "Invalid or expired token")
			return
		}

		ctx := context.WithValue(r.Context(), "user_id", userID)
		ctx = context.WithValue(ctx, "role", role)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
