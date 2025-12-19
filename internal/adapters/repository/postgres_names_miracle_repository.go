package repository

import (
	"database/sql"
	"fmt"
	"log"
	"numberniceic/internal/core/domain"
	"strings"
)

type PostgresNamesMiracleRepository struct {
	db *sql.DB
}

func NewPostgresNamesMiracleRepository(db *sql.DB) *PostgresNamesMiracleRepository {
	return &PostgresNamesMiracleRepository{db: db}
}

// getKlakiniColumn maps a day string to its corresponding database column name.
func getKlakiniColumn(day string) (string, error) {
	dayMapping := map[string]string{
		"sunday":     "k_sunday",
		"monday":     "k_monday",
		"tuesday":    "k_tuesday",
		"wednesday1": "k_wednesday1",
		"wednesday2": "k_wednesday2",
		"thursday":   "k_thursday",
		"friday":     "k_friday",
		"saturday":   "k_saturday",
	}
	col, ok := dayMapping[strings.ToLower(day)]
	if !ok {
		return "", fmt.Errorf("invalid day: %s", day)
	}
	return col, nil
}

// GetSimilarNames fetches up to a given limit of similar names with an offset.
func (r *PostgresNamesMiracleRepository) GetSimilarNames(name, day string, limit, offset int) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	query := fmt.Sprintf(`
        WITH filtered_names AS (
            SELECT 
                name_id,
                thname,
                satnum,
                shanum
            FROM names_miracle
            WHERE %s = false
        ),
        ranked_names AS (
            SELECT
                *,
                similarity(thname, $1) as sim
            FROM filtered_names
            WHERE similarity(thname, $1) > 0.1
        )
        SELECT 
            name_id,
            thname,
            satnum,
            shanum
        FROM ranked_names
        ORDER BY sim DESC
        LIMIT $2 OFFSET $3;
    `, klakiniColumn)

	return r.executeNameQuery(query, name, limit, offset)
}

// GetAuspiciousNames behaves identically to GetSimilarNames.
// The distinction and logic for finding "truly" auspicious names is handled in the service layer.
func (r *PostgresNamesMiracleRepository) GetAuspiciousNames(name, day string, limit, offset int) ([]domain.SimilarNameResult, error) {
	return r.GetSimilarNames(name, day, limit, offset)
}

func (r *PostgresNamesMiracleRepository) executeNameQuery(query string, args ...interface{}) ([]domain.SimilarNameResult, error) {
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("query execution failed: %w", err)
	}
	defer rows.Close()

	var results []domain.SimilarNameResult
	for rows.Next() {
		var res domain.SimilarNameResult
		var satNumStr, shaNumStr string
		if err := rows.Scan(&res.NameID, &res.ThName, &satNumStr, &shaNumStr); err != nil {
			log.Printf("Error scanning row: %v", err)
			continue
		}
		res.SatNum = strings.Split(strings.Trim(satNumStr, "{}"), ",")
		res.ShaNum = strings.Split(strings.Trim(shaNumStr, "{}"), ",")
		results = append(results, res)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %w", err)
	}

	return results, nil
}
