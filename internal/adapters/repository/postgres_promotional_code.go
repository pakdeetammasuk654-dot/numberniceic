package repository

import (
	"database/sql"
	"errors"
	"numberniceic/internal/core/domain"
	"time"
)

type PostgresPromotionalCodeRepository struct {
	db *sql.DB
}

func NewPostgresPromotionalCodeRepository(db *sql.DB) *PostgresPromotionalCodeRepository {
	return &PostgresPromotionalCodeRepository{db: db}
}

func (r *PostgresPromotionalCodeRepository) GetByCode(code string) (*domain.PromotionalCode, error) {
	query := `SELECT id, code, is_used, used_by_member_id, used_at, created_at FROM promotional_codes WHERE code = $1`
	var pc domain.PromotionalCode
	err := r.db.QueryRow(query, code).Scan(&pc.ID, &pc.Code, &pc.IsUsed, &pc.UsedByMemberID, &pc.UsedAt, &pc.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("code not found")
		}
		return nil, err
	}
	return &pc, nil
}

func (r *PostgresPromotionalCodeRepository) Redeem(codeID int, memberID int) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}

	// 1. Mark code as used
	queryCode := `UPDATE promotional_codes SET is_used = TRUE, used_by_member_id = $1, used_at = $2 WHERE id = $3 AND is_used = FALSE`
	result, err := tx.Exec(queryCode, memberID, time.Now(), codeID)
	if err != nil {
		tx.Rollback()
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		tx.Rollback()
		return errors.New("code already used or invalid")
	}

	// 2. Upgrade member status to VIP (Status 2)
	queryMember := `UPDATE member SET status = 2 WHERE id = $1`
	_, err = tx.Exec(queryMember, memberID)
	if err != nil {
		tx.Rollback()
		return err
	}

	return tx.Commit()
}

// GenerateCode is for admin/system use
func (r *PostgresPromotionalCodeRepository) GenerateCode(code string) error {
	query := `INSERT INTO promotional_codes (code) VALUES ($1)`
	_, err := r.db.Exec(query, code)
	return err
}

func (r *PostgresPromotionalCodeRepository) CreatePurchase(code string, ownerID int, productName string) error {
	query := `INSERT INTO promotional_codes (code, owner_member_id, product_name) VALUES ($1, $2, $3)`
	_, err := r.db.Exec(query, code, ownerID, productName)
	return err
}

func (r *PostgresPromotionalCodeRepository) GetByOwnerID(ownerID int) ([]domain.PromotionalCode, error) {
	query := `SELECT id, code, is_used, used_by_member_id, used_at, created_at, owner_member_id, COALESCE(product_name, '') 
	          FROM promotional_codes 
	          WHERE owner_member_id = $1 
	          ORDER BY created_at DESC`
	rows, err := r.db.Query(query, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var codes []domain.PromotionalCode
	for rows.Next() {
		var pc domain.PromotionalCode
		err := rows.Scan(&pc.ID, &pc.Code, &pc.IsUsed, &pc.UsedByMemberID, &pc.UsedAt, &pc.CreatedAt, &pc.OwnerMemberID, &pc.ProductName)
		if err != nil {
			return nil, err
		}
		codes = append(codes, pc)
	}
	return codes, nil
}
