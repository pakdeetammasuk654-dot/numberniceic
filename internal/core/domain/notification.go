package domain

import "time"

type UserNotification struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	Title     string    `json:"title"`
	Message   string    `json:"message"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

type AdminNotificationHistory struct {
	UserNotification
	Username string `json:"username"`
	Email    string `json:"email"`
}
