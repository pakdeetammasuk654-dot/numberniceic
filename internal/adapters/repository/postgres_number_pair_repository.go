package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"strings"

	"github.com/lib/pq"
)

type PostgresNumberPairRepository struct {
	db *sql.DB
}

func NewPostgresNumberPairRepository(db *sql.DB) *PostgresNumberPairRepository {
	return &PostgresNumberPairRepository{db: db}
}

func (r *PostgresNumberPairRepository) GetAll() ([]domain.NumberPairMeaning, error) {
	query := `
		SELECT n.pairnumber, n.pairtype, n.miracledetail, n.miracledesc, n.pairpoint, nc.category, nc.keywords
		FROM public.numbers n
		LEFT JOIN number_categories nc ON n.pairnumber = nc.pairnumber
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var meanings []domain.NumberPairMeaning
	for rows.Next() {
		var m domain.NumberPairMeaning
		var detailVip, pairType, pairNumber, miracleDesc, category sql.NullString
		var pairPoint sql.NullInt64
		var keywords []string

		if err := rows.Scan(&pairNumber, &pairType, &detailVip, &miracleDesc, &pairPoint, &category, pq.Array(&keywords)); err != nil {
			return nil, err
		}

		m.PairNumber = strings.TrimSpace(pairNumber.String)
		m.PairType = strings.TrimSpace(pairType.String)
		m.MiracleDetail = strings.TrimSpace(detailVip.String)
		m.MiracleDesc = strings.TrimSpace(miracleDesc.String)
		m.PairPoint = int(pairPoint.Int64)
		m.Category = strings.TrimSpace(category.String)
		m.Keywords = keywords
		m.Color = getPairTypeColor(m.PairType) // Assign color here

		meanings = append(meanings, m)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return meanings, nil
}

func getPairTypeColor(pairType string) string {
	trimmedType := strings.TrimSpace(pairType)
	switch trimmedType {
	case "D10":
		return "#2E7D32" // Dark Green
	case "D8":
		return "#43A047" // Green
	case "D5":
		return "#66BB6A" // Light Green
	case "R10":
		return "#C62828" // Dark Red
	case "R7":
		return "#E53935" // Red
	case "R5":
		return "#EF5350" // Light Red
	default:
		return "#9E9E9E" // Grey
	}
}
