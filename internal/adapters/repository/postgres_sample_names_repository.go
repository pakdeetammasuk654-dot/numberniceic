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
	rows, err := r.DB.Query("SELECT id, name, avatar_url, is_active FROM sample_names ORDER BY id ASC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sampleNames []domain.SampleName
	for rows.Next() {
		var sampleName domain.SampleName
		if err := rows.Scan(&sampleName.ID, &sampleName.Name, &sampleName.AvatarURL, &sampleName.IsActive); err != nil {
			return nil, err
		}
		sampleNames = append(sampleNames, sampleName)
	}

	return sampleNames, nil
}

func (r *PostgresSampleNamesRepository) SetActive(id int) error {
	tx, err := r.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Set all to false
	if _, err := tx.Exec("UPDATE sample_names SET is_active = false"); err != nil {
		return err
	}

	// 2. Set target to true
	if _, err := tx.Exec("UPDATE sample_names SET is_active = true WHERE id = $1", id); err != nil {
		return err
	}

	return tx.Commit()
}
