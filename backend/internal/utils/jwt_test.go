package utils

import (
	"os"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "test-secret-do-not-use-in-production-1234567890"

// setupTestSecret sets a known JWT_SECRET for the duration of a test
// and restores the previous value after the test finishes
func setupTestSecret(t *testing.T) {
	t.Helper()
	original := os.Getenv("JWT_SECRET")
	os.Setenv("JWT_SECRET", testSecret)
	t.Cleanup(func() {
		os.Setenv("JWT_SECRET", original)
	})
}

// TestValidateJWT_ValidToken verifies that a freshly issued token
// is accepted and the user_id and role claims are correctly extracted
func TestValidateJWT_ValidToken(t *testing.T) {
	setupTestSecret(t)

	tokenStr, err := GenerateJWT(42, "USER")
	if err != nil {
		t.Fatalf("GenerateJWT failed: %v", err)
	}

	userID, role, err := ValidateJWT(tokenStr)
	if err != nil {
		t.Fatalf("ValidateJWT rejected a valid token: %v", err)
	}
	if userID != 42 {
		t.Errorf("expected userID=42, got %d", userID)
	}
	if role != "USER" {
		t.Errorf("expected role=USER, got %q", role)
	}
}

// TestValidateJWT_ExpiredToken verifies that a token rejection of expired tokens
func TestValidateJWT_ExpiredToken(t *testing.T) {
	setupTestSecret(t)

	claims := jwt.MapClaims{
		"user_id": 42,
		"role":    "USER",
		"exp":     time.Now().Add(-1 * time.Hour).Unix(),
		"iat":     time.Now().Add(-2 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("failed to craft expired token: %v", err)
	}

	_, _, err = ValidateJWT(tokenStr)
	if err == nil {
		t.Fatal("expected error for expired token, got nil")
	}
}

// TestValidateJWT_AlgorithmConfusion_None verifies rejection of alg: none
func TestValidateJWT_AlgorithmConfusion_None(t *testing.T) {
	setupTestSecret(t)

	// Craft a token with no signature using SigningMethodNone
	claims := jwt.MapClaims{
		"user_id": 42,
		"role":    "USER",
		"exp":     time.Now().Add(1 * time.Hour).Unix(),
		"iat":     time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)

	tokenStr, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("failed to craft none alg token: %v", err)
	}

	_, _, err = ValidateJWT(tokenStr)
	if err == nil {
		t.Fatal("CRITICAL: ValidateJWT accepted a token with alg=none. This is an algorithm confusion vulnerability.")
	}
}

// TestValidateJWT_WrongSecret verifies that a token signed with a different
// secret is rejected
func TestValidateJWT_WrongSecret(t *testing.T) {
	setupTestSecret(t)

	claims := jwt.MapClaims{
		"user_id": 42,
		"role":    "USER",
		"exp":     time.Now().Add(1 * time.Hour).Unix(),
		"iat":     time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte("attacker-controlled-secret"))
	if err != nil {
		t.Fatalf("failed to craft token: %v", err)
	}

	_, _, err = ValidateJWT(tokenStr)
	if err == nil {
		t.Fatal("expected error for token signed with wrong secret, got nil")
	}
}

// TestValidateJWT_MalformedToken verifies that a non JWT string is rejected
func TestValidateJWT_MalformedToken(t *testing.T) {
	setupTestSecret(t)

	_, _, err := ValidateJWT("this.is.not-a-valid-jwt")
	if err == nil {
		t.Fatal("expected error for malformed token, got nil")
	}
}

// TestValidateJWT_MissingSecret verifies that ValidateJWT fails safely if the
// JWT_SECRET environment variable is not set, rather than accepting any token.
func TestValidateJWT_MissingSecret(t *testing.T) {
	original := os.Getenv("JWT_SECRET")
	os.Unsetenv("JWT_SECRET")
	t.Cleanup(func() {
		os.Setenv("JWT_SECRET", original)
	})

	// syntactically valid token must fail when the server has no secret
	tokenStr, _ := GenerateJWT(42, "USER")
	_, _, err := ValidateJWT(tokenStr)
	if err == nil {
		t.Fatal("expected error when JWT_SECRET is unset, got nil")
	}
}
