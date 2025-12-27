package domain

import "time"

type BuddhistDay struct {
	ID   int       `json:"id"`
	Date time.Time `json:"date"`
}
