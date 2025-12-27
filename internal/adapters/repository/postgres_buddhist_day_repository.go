package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"time"
)

type PostgresBuddhistDayRepository struct {
	db *sql.DB
}

func NewPostgresBuddhistDayRepository(db *sql.DB) *PostgresBuddhistDayRepository {
	return &PostgresBuddhistDayRepository{db: db}
}

func (r *PostgresBuddhistDayRepository) Create(date time.Time) error {
	_, err := r.db.Exec("INSERT INTO buddhist_days (date) VALUES ($1)", date)
	return err
}

func (r *PostgresBuddhistDayRepository) GetAll() ([]domain.BuddhistDay, error) {
	rows, err := r.db.Query("SELECT id, date FROM buddhist_days ORDER BY date ASC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var days []domain.BuddhistDay
	for rows.Next() {
		var d domain.BuddhistDay
		if err := rows.Scan(&d.ID, &d.Date); err != nil {
			return nil, err
		}
		days = append(days, d)
	}
	return days, nil
}

func (r *PostgresBuddhistDayRepository) Delete(id int) error {
	_, err := r.db.Exec("DELETE FROM buddhist_days WHERE id = $1", id)
	return err
}

func (r *PostgresBuddhistDayRepository) GetUpcoming(limit int) ([]domain.BuddhistDay, error) {
	rows, err := r.db.Query("SELECT id, date FROM buddhist_days WHERE date >= CURRENT_DATE ORDER BY date ASC LIMIT $1", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var days []domain.BuddhistDay
	for rows.Next() {
		var d domain.BuddhistDay
		if err := rows.Scan(&d.ID, &d.Date); err != nil {
			return nil, err
		}
		days = append(days, d)
	}
	return days, nil
}

func (r *PostgresBuddhistDayRepository) GetByDate(date time.Time) (*domain.BuddhistDay, error) {
	var d domain.BuddhistDay
	err := r.db.QueryRow("SELECT id, date FROM buddhist_days WHERE date = $1", date).Scan(&d.ID, &d.Date)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &d, nil
}
