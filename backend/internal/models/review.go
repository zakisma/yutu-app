package models

type Review struct {
	ID          int    `json:"id"`
	ReviewerID  int    `json:"reviewer_id"`
	RevieweeID  int    `json:"reviewee_id"`
	AuctionID   int    `json:"auction_id"`
	RatingStars int    `json:"rating_stars"`
	Comment     string `json:"comment"`
	CreatedAt   string `json:"created_at"`

	ReviewerName  string `json:"reviewer_name,omitempty"`
	ReviewerImage string `json:"reviewer_image,omitempty"`
}

type CreateReviewRequest struct {
	RevieweeID  int    `json:"reviewee_id" validate:"required,gt=0"`
	AuctionID   int    `json:"auction_id" validate:"required,gt=0"`
	RatingStars int    `json:"rating_stars" validate:"required,min=1,max=5"`
	Comment     string `json:"comment" validate:"required,max=500"`
}
