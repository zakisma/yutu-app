package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/zakisma/yutu-app/internal/utils"
)

const testSecret = "test-secret-12345"

// setupTestSecret sets JWT_SECRET for the test and restores it after
func setupTestSecret(t *testing.T) {
	t.Helper()
	original := os.Getenv("JWT_SECRET")
	os.Setenv("JWT_SECRET", testSecret)
	t.Cleanup(func() {
		os.Setenv("JWT_SECRET", original)
	})
}

// handler to get ok respnse when midlleware passes
var dummyHandler = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
})

// TestAuthMiddleware_RejectsMissingHeader ensures requests without an
// Authorization header are blocked with 401
func TestAuthMiddleware_RejectsMissingHeader(t *testing.T) {
	setupTestSecret(t)

	handler := AuthMiddleware(dummyHandler)
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

// TestAuthMiddleware_RejectsMalformedHeader tests that headers that aren't in the
// Bearer <token> format are rejected
func TestAuthMiddleware_RejectsMalformedHeader(t *testing.T) {
	setupTestSecret(t)

	cases := []struct {
		name   string
		header string
	}{
		{"NoBearerPrefix", "abcdef.token.here"},
		{"BearerWithoutToken", "Bearer "},
		{"WrongScheme", "Basic abcdef"},
		{"EmptyBearer", "Bearer"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			handler := AuthMiddleware(dummyHandler)
			req := httptest.NewRequest(http.MethodGet, "/protected", nil)
			req.Header.Set("Authorization", c.header)
			rec := httptest.NewRecorder()

			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("expected 401 for header %q, got %d", c.header, rec.Code)
			}
		})
	}
}

// TestAuthMiddleware_RejectsExpiredToken ensures expired tokens are blocked
func TestAuthMiddleware_RejectsExpiredToken(t *testing.T) {
	setupTestSecret(t)

	claims := jwt.MapClaims{
		"user_id": 42,
		"role":    "USER",
		"exp":     time.Now().Add(-1 * time.Hour).Unix(),
		"iat":     time.Now().Add(-2 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testSecret))

	handler := AuthMiddleware(dummyHandler)
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for expired token, got %d", rec.Code)
	}
}

// valid token must result in 200 and the handler should be able to read data from context
func TestAuthMiddleware_AcceptsValidToken_PopulatesContext(t *testing.T) {
	setupTestSecret(t)

	expectedUserID := 42
	expectedRole := "USER"
	tokenStr, err := utils.GenerateJWT(expectedUserID, expectedRole)
	if err != nil {
		t.Fatalf("GenerateJWT failed: %v", err)
	}

	var capturedUserID int
	var capturedRole string
	var contextOK bool

	contextChecker := func(w http.ResponseWriter, r *http.Request) {
		uid, uok := r.Context().Value("user_id").(int)
		role, rok := r.Context().Value("role").(string)
		capturedUserID = uid
		capturedRole = role
		contextOK = uok && rok
		w.WriteHeader(http.StatusOK)
	}

	handler := AuthMiddleware(http.HandlerFunc(contextChecker))
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !contextOK {
		t.Fatal("middleware did not populate user_id and role in context")
	}
	if capturedUserID != expectedUserID {
		t.Errorf("expected user_id=%d in context, got %d", expectedUserID, capturedUserID)
	}
	if capturedRole != expectedRole {
		t.Errorf("expected role=%q in context, got %q", expectedRole, capturedRole)
	}
}
