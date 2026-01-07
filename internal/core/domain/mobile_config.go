package domain

import "time"

type MobileWelcomeConfig struct {
	ID        int       `json:"id" db:"id"`
	Title     string    `json:"title" db:"title"`
	Body      string    `json:"body" db:"body"`
	IsActive  bool      `json:"is_active" db:"is_active"`
	Version   int       `json:"version" db:"version"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
