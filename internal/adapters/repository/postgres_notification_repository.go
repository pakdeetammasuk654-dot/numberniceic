package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
)

type PostgresNotificationRepository struct {
	db *sql.DB
}

func NewPostgresNotificationRepository(db *sql.DB) *PostgresNotificationRepository {
	return &PostgresNotificationRepository{db: db}
}

func (r *PostgresNotificationRepository) Create(n *domain.UserNotification) error {
	query := `
		INSERT INTO user_notifications (user_id, title, message)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	return r.db.QueryRow(query, n.UserID, n.Title, n.Message).Scan(&n.ID, &n.CreatedAt)
}

func (r *PostgresNotificationRepository) GetByUserID(userID int) ([]domain.UserNotification, error) {
	query := `
		SELECT id, user_id, title, message, is_read, created_at
		FROM user_notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []domain.UserNotification
	for rows.Next() {
		var n domain.UserNotification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Message, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, nil
}

func (r *PostgresNotificationRepository) MarkAsRead(id int) error {
	query := `UPDATE user_notifications SET is_read = true WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *PostgresNotificationRepository) CountUnread(userID int) (int, error) {
	query := `SELECT COUNT(*) FROM user_notifications WHERE user_id = $1 AND is_read = false`
	var count int
	err := r.db.QueryRow(query, userID).Scan(&count)
	return count, err
}

func (r *PostgresNotificationRepository) GetAllForAdmin(limit int) ([]domain.AdminNotificationHistory, error) {
	query := `
		SELECT n.id, n.user_id, n.title, n.message, n.is_read, n.created_at, m.username, m.email
		FROM user_notifications n
		JOIN member m ON n.user_id = m.id
		ORDER BY n.created_at DESC
		LIMIT $1
	`
	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var history []domain.AdminNotificationHistory
	for rows.Next() {
		var h domain.AdminNotificationHistory
		if err := rows.Scan(&h.ID, &h.UserID, &h.Title, &h.Message, &h.IsRead, &h.CreatedAt, &h.Username, &h.Email); err != nil {
			return nil, err
		}
		history = append(history, h)
	}
	return history, nil
}
