package domain

import "time"

type SavedName struct {
	ID         int        `json:"id"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	DeletedAt  *time.Time `json:"deleted_at"`
	UserID     int        `json:"user_id"`
	Name       string     `json:"name"`
	BirthDay   string     `json:"birth_day"`
	TotalScore int        `json:"total_score"`
	SatSum     int        `json:"sat_sum"`
	ShaSum     int        `json:"sha_sum"`
}
