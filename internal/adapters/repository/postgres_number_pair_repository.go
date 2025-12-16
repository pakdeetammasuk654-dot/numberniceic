package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"strings"
)

type PostgresNumberPairRepository struct {
	db *sql.DB
}

func NewPostgresNumberPairRepository(db *sql.DB) *PostgresNumberPairRepository {
	return &PostgresNumberPairRepository{db: db}
}

func (r *PostgresNumberPairRepository) GetAll() ([]domain.NumberPairMeaning, error) {
	rows, err := r.db.Query("SELECT pairnumber, pairtype, miracledetail, miracledesc, pairpoint FROM public.numbers")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var meanings []domain.NumberPairMeaning
	for rows.Next() {
		var m domain.NumberPairMeaning
		var detailVip, pairType, pairNumber, miracleDesc sql.NullString
		var pairPoint sql.NullInt64

		if err := rows.Scan(&pairNumber, &pairType, &detailVip, &miracleDesc, &pairPoint); err != nil {
			return nil, err
		}

		m.PairNumber = strings.TrimSpace(pairNumber.String)
		m.PairType = strings.TrimSpace(pairType.String)
		m.MiracleDetail = strings.TrimSpace(detailVip.String)
		m.MiracleDesc = strings.TrimSpace(miracleDesc.String)
		m.PairPoint = int(pairPoint.Int64)
		m.Color = service.GetPairTypeColor(m.PairType) // Assign color here

		meanings = append(meanings, m)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return meanings, nil
}
