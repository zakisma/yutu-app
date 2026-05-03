package utils

import (
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// GenerateJWT creates a new token valid for 24 hours
func GenerateJWT(userID int, role string) (string, error) {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		return "", errors.New("JWT_SECRET environment variable is not set")
	}

	claims := jwt.MapClaims{
		"user_id": userID,
		"role":    role,
		"exp":     time.Now().Add(time.Hour * 24).Unix(),
		"iat":     time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// takes a raw token string, parses it, and returns the userid and role
func ValidateJWT(tokenStr string) (int, string, error) {
	secretKey := os.Getenv("JWT_SECRET")
	if secretKey == "" {
		return 0, "", errors.New("JWT_SECRET not set")
	}

	// parse the token
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		if token.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, errors.New("unexpected signing algorithm")
		}
		return []byte(secretKey), nil
	})

	if err != nil || !token.Valid {
		return 0, "", errors.New("invalid or expired token")
	}

	// extract the claims
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return 0, "", errors.New("invalid token claims")
	}

	userIDFloat, ok := claims["user_id"].(float64)
	if !ok {
		return 0, "", errors.New("user_id missing from token")
	}

	role, _ := claims["role"].(string)

	return int(userIDFloat), role, nil
}
