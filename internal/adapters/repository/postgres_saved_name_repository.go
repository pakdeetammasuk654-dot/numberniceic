package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresSavedNameRepository struct {
	db *sql.DB
}

func NewPostgresSavedNameRepository(db *sql.DB) ports.SavedNameRepository {
	return &PostgresSavedNameRepository{db: db}
}

func (r *PostgresSavedNameRepository) Save(savedName *domain.SavedName) error {
	query := `
		INSERT INTO saved_names (created_at, updated_at, user_id, name, birth_day, total_score, sat_sum, sha_sum)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`
	now := time.Now()
	err := r.db.QueryRow(query, now, now, savedName.UserID, savedName.Name, savedName.BirthDay, savedName.TotalScore, savedName.SatSum, savedName.ShaSum).Scan(&savedName.ID)
	if err != nil {
		return err
	}
	savedName.CreatedAt = now
	savedName.UpdatedAt = now
	return nil
}

func (r *PostgresSavedNameRepository) GetByUserID(userID int) ([]domain.SavedName, error) {
	query := `
		SELECT id, created_at, updated_at, user_id, name, birth_day, total_score, sat_sum, sha_sum
		FROM saved_names
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var savedNames []domain.SavedName
	for rows.Next() {
		var s domain.SavedName
		err := rows.Scan(&s.ID, &s.CreatedAt, &s.UpdatedAt, &s.UserID, &s.Name, &s.BirthDay, &s.TotalScore, &s.SatSum, &s.ShaSum)
		if err != nil {
			return nil, err
		}
		savedNames = append(savedNames, s)
	}
	return savedNames, nil
}

func (r *PostgresSavedNameRepository) Delete(id int, userID int) error {
	query := `
		UPDATE saved_names
		SET deleted_at = $1
		WHERE id = $2 AND user_id = $3
	`
	_, err := r.db.Exec(query, time.Now(), id, userID)
	return err
}
