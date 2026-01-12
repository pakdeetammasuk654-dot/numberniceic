package domain

import (
	"encoding/json"
	"time"
)

type UserNotification struct {
	ID        int             `json:"id"`
	UserID    int             `json:"user_id"`
	Title     string          `json:"title"`
	Message   string          `json:"message"`
	IsRead    bool            `json:"is_read"`
	Data      json.RawMessage `json:"data,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
}

type AdminNotificationHistory struct {
	UserNotification
	Username string `json:"username"`
	Email    string `json:"email"`
}
