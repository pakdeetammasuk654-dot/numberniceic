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

func (r *PostgresBuddhistDayRepository) Create(day *domain.BuddhistDay) error {
	_, err := r.db.Exec("INSERT INTO buddhist_days (date, title, message) VALUES ($1, $2, $3)", day.Date, day.Title, day.Message)
	return err
}

func (r *PostgresBuddhistDayRepository) GetAll() ([]domain.BuddhistDay, error) {
	rows, err := r.db.Query("SELECT id, date, COALESCE(title, ''), COALESCE(message, '') FROM buddhist_days ORDER BY date ASC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var days []domain.BuddhistDay
	for rows.Next() {
		var d domain.BuddhistDay
		if err := rows.Scan(&d.ID, &d.Date, &d.Title, &d.Message); err != nil {
			return nil, err
		}
		days = append(days, d)
	}
	return days, nil
}

func (r *PostgresBuddhistDayRepository) GetPaginated(offset, limit int) ([]domain.BuddhistDay, int, error) {
	// Get total count (future days only)
	var total int
	err := r.db.QueryRow("SELECT COUNT(*) FROM buddhist_days WHERE date >= CURRENT_DATE").Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// Get paginated rows (future days only)
	rows, err := r.db.Query("SELECT id, date, COALESCE(title, ''), COALESCE(message, '') FROM buddhist_days WHERE date >= CURRENT_DATE ORDER BY date ASC LIMIT $1 OFFSET $2", limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var days []domain.BuddhistDay
	for rows.Next() {
		var d domain.BuddhistDay
		if err := rows.Scan(&d.ID, &d.Date, &d.Title, &d.Message); err != nil {
			return nil, 0, err
		}
		days = append(days, d)
	}
	return days, total, nil
}

func (r *PostgresBuddhistDayRepository) Delete(id int) error {
	_, err := r.db.Exec("DELETE FROM buddhist_days WHERE id = $1", id)
	return err
}

func (r *PostgresBuddhistDayRepository) Update(day *domain.BuddhistDay) error {
	_, err := r.db.Exec("UPDATE buddhist_days SET title = $2, message = $3 WHERE id = $1", day.ID, day.Title, day.Message)
	return err
}

func (r *PostgresBuddhistDayRepository) GetUpcoming(limit int) ([]domain.BuddhistDay, error) {
	rows, err := r.db.Query("SELECT id, date, COALESCE(title, ''), COALESCE(message, '') FROM buddhist_days WHERE date >= CURRENT_DATE ORDER BY date ASC LIMIT $1", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var days []domain.BuddhistDay
	for rows.Next() {
		var d domain.BuddhistDay
		if err := rows.Scan(&d.ID, &d.Date, &d.Title, &d.Message); err != nil {
			return nil, err
		}
		days = append(days, d)
	}
	return days, nil
}

func (r *PostgresBuddhistDayRepository) GetByDate(date time.Time) (*domain.BuddhistDay, error) {
	var d domain.BuddhistDay
	err := r.db.QueryRow("SELECT id, date, COALESCE(title, ''), COALESCE(message, '') FROM buddhist_days WHERE date = $1", date).Scan(&d.ID, &d.Date, &d.Title, &d.Message)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &d, nil
}
