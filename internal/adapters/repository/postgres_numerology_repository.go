package repository

import (
	"database/sql"
	"fmt"
	"numberniceic/internal/core/domain"
)

// PostgresNumerologyRepository is a generic adapter that fetches numerology data from a specified table.
type PostgresNumerologyRepository struct {
	db        *sql.DB
	tableName string
}

// NewPostgresNumerologyRepository creates a new repository instance for a specific table.
func NewPostgresNumerologyRepository(db *sql.DB, tableName string) *PostgresNumerologyRepository {
	return &PostgresNumerologyRepository{
		db:        db,
		tableName: tableName,
	}
}

// GetAll retrieves all numerology records from the configured table.
func (r *PostgresNumerologyRepository) GetAll() ([]domain.Numerology, error) {
	// Note: Table names cannot be parameterized in SQL queries for security reasons (SQL Injection).
	// However, since the table name comes from our internal configuration (main.go), it is safe here.
	query := fmt.Sprintf("SELECT char_key, %s FROM public.%s", r.getValueColumnName(), r.tableName)
	
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var numerologies []domain.Numerology
	for rows.Next() {
		var n domain.Numerology
		if err := rows.Scan(&n.Character, &n.Value); err != nil {
			return nil, err
		}
		numerologies = append(numerologies, n)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return numerologies, nil
}

// getValueColumnName determines the value column name based on the table name.
// This is a small helper to handle the schema difference (sat_value vs sha_value).
func (r *PostgresNumerologyRepository) getValueColumnName() string {
	if r.tableName == "sat_nums" {
		return "sat_value"
	} else if r.tableName == "sha_nums" {
		return "sha_value"
	}
	// Default fallback or error handling could go here
	return "value" 
}
