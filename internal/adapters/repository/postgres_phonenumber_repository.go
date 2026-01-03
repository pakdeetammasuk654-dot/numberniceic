package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"strings"
)

type PostgresPhoneNumberRepository struct {
	db *sql.DB
}

func NewPostgresPhoneNumberRepository(db *sql.DB) ports.PhoneNumberRepository {
	return &PostgresPhoneNumberRepository{db: db}
}

func (r *PostgresPhoneNumberRepository) GetAll() ([]domain.PhoneNumberSell, error) {
	query := `
		SELECT pnumber_id, pnumber_position, pnumber_num, pnumber_sum, pnumber_price, phone_group, sell_status, prefix_group
		FROM phonenumber_sell
		ORDER BY pnumber_id ASC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var numbers []domain.PhoneNumberSell
	for rows.Next() {
		var p domain.PhoneNumberSell
		err := rows.Scan(
			&p.PNumberID,
			&p.PNumberPosition,
			&p.PNumberNum,
			&p.PNumberSum,
			&p.PNumberPrice,
			&p.PhoneGroup,
			&p.SellStatus,
			&p.PrefixGroup,
		)
		if err != nil {
			return nil, err
		}
		p.PNumberNum = strings.TrimSpace(p.PNumberNum)
		numbers = append(numbers, p)
	}
	return numbers, nil
}

func (r *PostgresPhoneNumberRepository) GetPaged(offset, limit int) ([]domain.PhoneNumberSell, error) {
	query := `
		SELECT pnumber_id, pnumber_position, pnumber_num, pnumber_sum, pnumber_price, phone_group, sell_status, prefix_group
		FROM phonenumber_sell
		ORDER BY pnumber_id ASC
		OFFSET $1 LIMIT $2
	`
	rows, err := r.db.Query(query, offset, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var numbers []domain.PhoneNumberSell
	for rows.Next() {
		var p domain.PhoneNumberSell
		err := rows.Scan(
			&p.PNumberID,
			&p.PNumberPosition,
			&p.PNumberNum,
			&p.PNumberSum,
			&p.PNumberPrice,
			&p.PhoneGroup,
			&p.SellStatus,
			&p.PrefixGroup,
		)
		if err != nil {
			return nil, err
		}
		p.PNumberNum = strings.TrimSpace(p.PNumberNum)
		numbers = append(numbers, p)
	}
	return numbers, nil
}

func (r *PostgresPhoneNumberRepository) Count() (int, error) {
	var count int
	err := r.db.QueryRow("SELECT COUNT(*) FROM phonenumber_sell").Scan(&count)
	return count, err
}

func (r *PostgresPhoneNumberRepository) GetByPrefix(prefix string) ([]domain.PhoneNumberSell, error) {
	query := `
		SELECT pnumber_id, pnumber_position, pnumber_num, pnumber_sum, pnumber_price, phone_group, sell_status, prefix_group
		FROM phonenumber_sell
		WHERE prefix_group = $1
		ORDER BY pnumber_id ASC
	`
	rows, err := r.db.Query(query, prefix)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var numbers []domain.PhoneNumberSell
	for rows.Next() {
		var p domain.PhoneNumberSell
		err := rows.Scan(
			&p.PNumberID,
			&p.PNumberPosition,
			&p.PNumberNum,
			&p.PNumberSum,
			&p.PNumberPrice,
			&p.PhoneGroup,
			&p.SellStatus,
			&p.PrefixGroup,
		)
		if err != nil {
			return nil, err
		}
		p.PNumberNum = strings.TrimSpace(p.PNumberNum)
		numbers = append(numbers, p)
	}
	return numbers, nil
}
