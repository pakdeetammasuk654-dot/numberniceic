package domain

import "time"

type WalletColor struct {
	ID          int       `json:"id"`
	DayOfWeek   int       `json:"day_of_week"` // 0=Sunday, 1=Monday, ..., 6=Saturday
	ColorName   string    `json:"color_name"`
	ColorHex    string    `json:"color_hex"`
	Description string    `json:"description"`
	UpdatedAt   time.Time `json:"updated_at"`
}
