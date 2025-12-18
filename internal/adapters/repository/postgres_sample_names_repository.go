package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
)

type PostgresSampleNamesRepository struct {
	DB *sql.DB
}

func NewPostgresSampleNamesRepository(db *sql.DB) *PostgresSampleNamesRepository {
	return &PostgresSampleNamesRepository{DB: db}
}

func (r *PostgresSampleNamesRepository) GetAll() ([]domain.SampleName, error) {
	rows, err := r.DB.Query("SELECT name, avatar_url FROM sample_names")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sampleNames []domain.SampleName
	for rows.Next() {
		var sampleName domain.SampleName
		if err := rows.Scan(&sampleName.Name, &sampleName.AvatarURL); err != nil {
			return nil, err
		}
		sampleNames = append(sampleNames, sampleName)
	}

	return sampleNames, nil
}
