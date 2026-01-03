package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"strings"

	"github.com/lib/pq"
)

type PostgresNumberCategoryRepository struct {
	db *sql.DB
}

func NewPostgresNumberCategoryRepository(db *sql.DB) *PostgresNumberCategoryRepository {
	return &PostgresNumberCategoryRepository{db: db}
}

func (r *PostgresNumberCategoryRepository) GetAll() ([]domain.NumberCategory, error) {
	rows, err := r.db.Query("SELECT pairnumber, category, number_type, keywords FROM public.number_categories")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var categories []domain.NumberCategory
	for rows.Next() {
		var c domain.NumberCategory
		var pairNumber, category, numberType sql.NullString

		if err := rows.Scan(&pairNumber, &category, &numberType, pq.Array(&c.Keywords)); err != nil {
			return nil, err
		}

		c.PairNumber = strings.TrimSpace(pairNumber.String)
		c.Category = strings.TrimSpace(category.String)
		c.NumberType = strings.TrimSpace(numberType.String)
		// keywords are already scanned into c.Keywords by pq.Array

		if c.PairNumber != "" && c.Category != "" {
			categories = append(categories, c)
		}
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return categories, nil
}
