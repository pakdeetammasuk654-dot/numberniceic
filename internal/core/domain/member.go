package domain

import "time"

type Member struct {
	ID             int        `json:"id"`
	Username       string     `json:"username"`
	Password       string     `json:"-"`
	Email          string     `json:"email"`
	Tel            string     `json:"tel"`
	Status         int        `json:"status"`
	DayOfBirth     *int       `json:"day_of_birth"` // 0=Sunday, 1=Monday, ..., 6=Saturday
	AssignedColors string     `json:"assigned_colors"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	DeletedAt      *time.Time `json:"deleted_at"`
}

const (
	// Status Constants
	StatusMember = 1
	StatusVIP    = 2
)

func (m *Member) IsVIP() bool {
	return m.Status == StatusVIP || m.Status == 9
}
