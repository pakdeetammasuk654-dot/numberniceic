package domain

import "time"

type Member struct {
	ID        int        `json:"id"`
	Username  string     `json:"username"`
	Password  string     `json:"-"`
	Email     string     `json:"email"`
	Tel       string     `json:"tel"`
	Status    int        `json:"status"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at"`
}

const (
	// Status Constants
	StatusMember = 1
	StatusVIP    = 2
)

func (m *Member) IsVIP() bool {
	return m.Status == StatusVIP || m.Status == 9
}
