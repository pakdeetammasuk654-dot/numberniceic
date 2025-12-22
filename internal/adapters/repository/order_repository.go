package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresOrderRepository struct {
	db *sql.DB
}

func NewPostgresOrderRepository(db *sql.DB) ports.OrderRepository {
	return &PostgresOrderRepository{db: db}
}

func (r *PostgresOrderRepository) Create(order *domain.Order) error {
	query := `
		INSERT INTO orders (ref_no, user_id, amount, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`
	order.CreatedAt = time.Now()
	order.UpdatedAt = time.Now()

	err := r.db.QueryRow(query,
		order.RefNo,
		order.UserID,
		order.Amount,
		order.Status,
		order.CreatedAt,
		order.UpdatedAt,
	).Scan(&order.ID)

	return err
}

func (r *PostgresOrderRepository) GetByRefNo(refNo string) (*domain.Order, error) {
	query := `
		SELECT id, ref_no, user_id, amount, status, created_at, updated_at
		FROM orders
		WHERE ref_no = $1
	`

	var order domain.Order
	err := r.db.QueryRow(query, refNo).Scan(
		&order.ID,
		&order.RefNo,
		&order.UserID,
		&order.Amount,
		&order.Status,
		&order.CreatedAt,
		&order.UpdatedAt,
	)

	if err != nil {
		return nil, err
	}

	return &order, nil
}

func (r *PostgresOrderRepository) UpdateStatus(refNo string, status string) error {
	query := `
		UPDATE orders
		SET status = $1, updated_at = $2
		WHERE ref_no = $3
	`
	_, err := r.db.Exec(query, status, time.Now(), refNo)
	return err
}
