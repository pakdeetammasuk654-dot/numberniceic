package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"strings"
)

type PostgresKlakiniRepository struct {
	db *sql.DB
}

func NewPostgresKlakiniRepository(db *sql.DB) *PostgresKlakiniRepository {
	return &PostgresKlakiniRepository{db: db}
}

func (r *PostgresKlakiniRepository) GetAll() ([]domain.Klakini, error) {
	rows, err := r.db.Query("SELECT day, kakis FROM public.kakis_day")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var klakinis []domain.Klakini
	for rows.Next() {
		var k domain.Klakini
		if err := rows.Scan(&k.Day, &k.BadChars); err != nil {
			return nil, err
		}
		// Normalize the day to lowercase for consistent matching
		k.Day = strings.ToLower(strings.TrimSpace(k.Day))
		klakinis = append(klakinis, k)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return klakinis, nil
}

func (r *PostgresKlakiniRepository) GetByDay(day string) (domain.Klakini, error) {
	var k domain.Klakini
	query := "SELECT day, kakis FROM public.kakis_day WHERE lower(trim(day)) = $1"
	err := r.db.QueryRow(query, strings.ToLower(strings.TrimSpace(day))).Scan(&k.Day, &k.BadChars)
	if err != nil {
		if err == sql.ErrNoRows {
			return domain.Klakini{}, nil // Return empty struct and no error if not found
		}
		return domain.Klakini{}, err
	}
	k.Day = strings.ToLower(strings.TrimSpace(k.Day))
	return k, nil
}
