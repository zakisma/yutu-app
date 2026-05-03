package models

import (
	"time"
)

type User struct {
	ID              int       `json:"id" db:"id"`
	Email           string    `json:"email" db:"email"`
	PasswordHash    string    `json:"-" db:"password_hash"`
	FullName        string    `json:"full_name" db:"full_name"`
	Role            string    `json:"role" db:"role"`
	IsVerified      bool      `json:"is_verified" db:"is_verified"`
	ProfileImageURL string    `json:"profile_image_url"`
	PhoneNumber     string    `json:"phone_number" validate:"omitempty,e164"`
	Address         string    `json:"address"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
}

type UserRegisterRequest struct {
	Email    string `json:"email" validate:"required,email,max=255"`
	Password string `json:"password" validate:"required,min=6,max=72"`
	FullName string `json:"full_name" validate:"required,max=100"`
}

type UserLoginRequest struct {
	Email    string `json:"email" validate:"required,email,max=255"`
	Password string `json:"password" validate:"required,max=72"`
}

type UpdateProfileRequest struct {
	ProfileImageURL string `json:"profile_image_url" validate:"omitempty,url,max=500"`
	PhoneNumber     string `json:"phone_number" validate:"omitempty,e164"`
	Address         string `json:"address" validate:"max=1000"`
}
