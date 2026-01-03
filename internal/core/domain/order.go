package domain

import "time"

type Order struct {
	ID     int     `json:"id" db:"id"`
	RefNo  string  `json:"ref_no" db:"ref_no"`
	UserID *int    `json:"user_id" db:"user_id"` // Pointer for nullable
	Amount float64 `json:"amount" db:"amount"`
	Status string  `json:"status" db:"status"` // pending, paid, verified, failed

	// Shop Fields
	ProductName  string  `json:"product_name" db:"product_name"`
	ProductImage string  `json:"product_image" db:"-"` // From joined products table
	SlipURL      string  `json:"slip_url" db:"slip_url"`
	PromoCodeID  *int    `json:"promo_code_id" db:"promo_code_id"`
	Username     *string `json:"username" db:"-"` // Populated via join

	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
