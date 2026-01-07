package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
)

type PostgresMobileConfigRepository struct {
	db *sql.DB
}

func NewPostgresMobileConfigRepository(db *sql.DB) *PostgresMobileConfigRepository {
	return &PostgresMobileConfigRepository{db: db}
}

func (r *PostgresMobileConfigRepository) GetLatestWelcomeConfig() (*domain.MobileWelcomeConfig, error) {
	query := `SELECT id, title, body, is_active, version, created_at FROM mobile_welcome_configs ORDER BY id DESC LIMIT 1`
	row := r.db.QueryRow(query)

	var config domain.MobileWelcomeConfig
	err := row.Scan(&config.ID, &config.Title, &config.Body, &config.IsActive, &config.Version, &config.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &config, nil
}

func (r *PostgresMobileConfigRepository) UpdateWelcomeConfig(title, body string, isActive bool) error {
	// We insert a new version to keep history, or update current?
	// Requirement says "System to manage", better to just update the single active record or insert new as latest.
	// Let's insert new one incrementing version.

	// Get current version first
	current, _ := r.GetLatestWelcomeConfig()
	newVersion := 1
	if current != nil {
		newVersion = current.Version + 1
	}

	query := `INSERT INTO mobile_welcome_configs (title, body, is_active, version) VALUES ($1, $2, $3, $4)`
	_, err := r.db.Exec(query, title, body, isActive, newVersion)
	return err
}
