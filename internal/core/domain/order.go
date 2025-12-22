package domain

import "time"

type Order struct {
	ID        int       `json:"id" db:"id"`
	RefNo     string    `json:"ref_no" db:"ref_no"`
	UserID    *int      `json:"user_id" db:"user_id"` // Pointer for nullable
	Amount    float64   `json:"amount" db:"amount"`
	Status    string    `json:"status" db:"status"` // pending, paid, failed
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
