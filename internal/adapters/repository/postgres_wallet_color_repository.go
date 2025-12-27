package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresWalletColorRepository struct {
	db *sql.DB
}

func NewPostgresWalletColorRepository(db *sql.DB) ports.WalletColorRepository {
	return &PostgresWalletColorRepository{db: db}
}

func (r *PostgresWalletColorRepository) GetAll() ([]domain.WalletColor, error) {
	rows, err := r.db.Query("SELECT id, day_of_week, color_name, color_hex, description, updated_at FROM wallet_colors ORDER BY day_of_week ASC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var colors []domain.WalletColor
	for rows.Next() {
		var c domain.WalletColor
		if err := rows.Scan(&c.ID, &c.DayOfWeek, &c.ColorName, &c.ColorHex, &c.Description, &c.UpdatedAt); err != nil {
			return nil, err
		}
		colors = append(colors, c)
	}
	return colors, nil
}

func (r *PostgresWalletColorRepository) GetByDay(dayOfWeek int) (*domain.WalletColor, error) {
	var c domain.WalletColor
	err := r.db.QueryRow("SELECT id, day_of_week, color_name, color_hex, description, updated_at FROM wallet_colors WHERE day_of_week = $1", dayOfWeek).
		Scan(&c.ID, &c.DayOfWeek, &c.ColorName, &c.ColorHex, &c.Description, &c.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &c, nil
}

func (r *PostgresWalletColorRepository) Update(color *domain.WalletColor) error {
	_, err := r.db.Exec("UPDATE wallet_colors SET color_name = $1, color_hex = $2, description = $3, updated_at = $4 WHERE day_of_week = $5",
		color.ColorName, color.ColorHex, color.Description, time.Now(), color.DayOfWeek)
	return err
}
