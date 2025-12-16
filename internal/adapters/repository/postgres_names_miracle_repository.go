package repository

import (
	"database/sql"
	"fmt"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"strings"

	"github.com/lib/pq"
)

type PostgresNamesMiracleRepository struct {
	db *sql.DB
}

func NewPostgresNamesMiracleRepository(db *sql.DB) *PostgresNamesMiracleRepository {
	return &PostgresNamesMiracleRepository{db: db}
}

func (r *PostgresNamesMiracleRepository) GetSimilarNames(name, day string, limit int) ([]domain.SimilarNameResult, error) {
	return r.getNames(name, day, limit, false)
}

func (r *PostgresNamesMiracleRepository) GetAuspiciousNames(name, day string, limit int) ([]domain.SimilarNameResult, error) {
	return r.getNames(name, day, limit, true)
}

func (r *PostgresNamesMiracleRepository) getNames(name, day string, limit int, filterAuspicious bool) ([]domain.SimilarNameResult, error) {
	baseQuery := `
		SELECT 
			name_id, thname, satnum, shanum, t_sat, t_sha,
			k_sunday, k_monday, k_tuesday, k_wednesday1, k_wednesday2, k_thursday, k_friday, k_saturday,
			levenshtein($1, thname) as distance
		FROM public.names_miracle
	`
	var whereClauses []string
	dayColumn := getDayColumn(day)
	if dayColumn != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("%s = false", pq.QuoteIdentifier(dayColumn)))
	}
	if filterAuspicious {
		auspiciousSet := "ARRAY['D10', 'D8', 'D5']"
		whereClauses = append(whereClauses, fmt.Sprintf("%s @> t_sat", auspiciousSet))
		whereClauses = append(whereClauses, fmt.Sprintf("%s @> t_sha", auspiciousSet))
	}
	fullWhereClause := ""
	if len(whereClauses) > 0 {
		fullWhereClause = "WHERE " + strings.Join(whereClauses, " AND ")
	}
	finalQuery := fmt.Sprintf("%s %s ORDER BY distance LIMIT $2", baseQuery, fullWhereClause)

	rows, err := r.db.Query(finalQuery, name, limit)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var results []domain.SimilarNameResult
	for rows.Next() {
		var res domain.SimilarNameResult
		var tSatStr, tShaStr []string // Temporary string slices

		err := rows.Scan(
			&res.NameID, &res.ThName,
			pq.Array(&res.SatNum), pq.Array(&res.ShaNum),
			pq.Array(&tSatStr), pq.Array(&tShaStr), // Scan into temp slices
			&res.KSunday, &res.KMonday, &res.KTuesday,
			&res.KWednesday1, &res.KWednesday2, &res.KThursday, &res.KFriday, &res.KSaturday,
			&res.Distance,
		)
		if err != nil {
			return nil, fmt.Errorf("row scan failed: %w", err)
		}

		// Convert string slices to PairTypeInfo slices
		res.TSat = make([]domain.PairTypeInfo, len(tSatStr))
		for i, t := range tSatStr {
			res.TSat[i] = domain.PairTypeInfo{Type: t, Color: service.GetPairTypeColor(t)}
		}
		res.TSha = make([]domain.PairTypeInfo, len(tShaStr))
		for i, t := range tShaStr {
			res.TSha[i] = domain.PairTypeInfo{Type: t, Color: service.GetPairTypeColor(t)}
		}

		if len(res.SatNum) > 0 {
			scoreQuery := `SELECT COALESCE(SUM(pairpoint), 0) FROM public.numbers WHERE pairnumber = ANY($1)`
			err := r.db.QueryRow(scoreQuery, pq.Array(res.SatNum)).Scan(&res.TotalScore)
			if err != nil {
				fmt.Printf("Warning: could not calculate score for name %s: %v\n", res.ThName, err)
				res.TotalScore = 0
			}
		} else {
			res.TotalScore = 0
		}
		results = append(results, res)
	}
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("rows iteration error: %w", err)
	}
	return results, nil
}

func getDayColumn(day string) string {
	switch strings.ToLower(day) {
	case "sunday":
		return "k_sunday"
	case "monday":
		return "k_monday"
	case "tuesday":
		return "k_tuesday"
	case "wednesday1":
		return "k_wednesday1"
	case "wednesday2":
		return "k_wednesday2"
	case "thursday":
		return "k_thursday"
	case "friday":
		return "k_friday"
	case "saturday":
		return "k_saturday"
	default:
		return ""
	}
}
