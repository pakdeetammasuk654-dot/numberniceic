package repository

import (
	"database/sql"
	"fmt"
	"log"
	"numberniceic/internal/core/domain"
	"strings"

	"github.com/lib/pq"
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

// getFirstConsonant extracts the first consonant from a Thai name, skipping leading vowels.
func getFirstConsonant(name string) string {
	runes := []rune(name)
	for _, r := range runes {
		// Skip Thai leading vowels
		switch r {
		case 'เ', 'แ', 'โ', 'ใ', 'ไ':
			continue
		default:
			return string(r)
		}
	}
	// Fallback: if no consonant found (unlikely for valid names), return first char or empty
	if len(runes) > 0 {
		return string(runes[0])
	}
	return ""
}

// GetSimilarNames fetches up to a given limit of similar names with an offset.
func (r *PostgresNamesMiracleRepository) GetSimilarNames(name, day string, limit, offset int, allowKlakini bool) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	// Build the WHERE clause for Klakini dynamically
	klakiniWhereClause := ""
	if !allowKlakini {
		klakiniWhereClause = fmt.Sprintf("AND %s = false", klakiniColumn)
	}

	query := fmt.Sprintf(`
        WITH filtered_names AS (
            SELECT 
                name_id,
                thname,
                satnum,
                shanum
            FROM names_miracle
            WHERE 1=1 %s
        ),
        ranked_names AS (
            SELECT
                *,
                similarity(thname, $1) as sim
            FROM filtered_names
            WHERE similarity(thname, $1) > 0.1 -- Keep this for the "similar" search
        )
        SELECT 
            name_id,
            thname,
            satnum,
            shanum,
            sim -- Return the similarity score
        FROM ranked_names
        ORDER BY sim DESC
        LIMIT $2 OFFSET $3;
    `, klakiniWhereClause)

	return r.executeNameQuery(query, name, limit, offset)
}

// GetAuspiciousNames fetches names for the auspicious search, which has different filtering rules.
func (r *PostgresNamesMiracleRepository) GetAuspiciousNames(name, day string, limit, offset int, allowKlakini bool) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	// Build the WHERE clause for Klakini dynamically
	klakiniWhereClause := ""
	if !allowKlakini {
		klakiniWhereClause = fmt.Sprintf("AND %s = false", klakiniColumn)
	}

	// This query is for finding candidates for auspicious names. It does NOT filter by similarity > 0.1
	// to ensure we can search the whole table if needed.
	query := fmt.Sprintf(`
        WITH filtered_names AS (
            SELECT 
                name_id,
                thname,
                satnum,
                shanum
            FROM names_miracle
            WHERE 1=1 %s
        ),
        ranked_names AS (
            SELECT
                *,
                similarity(thname, $1) as sim
            FROM filtered_names
        )
        SELECT 
            name_id,
            thname,
            satnum,
            shanum,
            sim -- Return the similarity score
        FROM ranked_names
        ORDER BY sim DESC
        LIMIT $2 OFFSET $3;
    `, klakiniWhereClause)

	return r.executeNameQuery(query, name, limit, offset)
}

func (r *PostgresNamesMiracleRepository) GetFallbackNames(name, day string, limit int, allowKlakini bool, excludedIDs []int) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	klakiniWhereClause := ""
	if !allowKlakini {
		klakiniWhereClause = fmt.Sprintf("AND %s = false", klakiniColumn)
	}

	// Step 1: Try to find names starting with the same first consonant
	firstConsonant := getFirstConsonant(name)

	log.Printf("GetFallbackNames Step 1: name=%s, day=%s, limit=%d, consonant=%s", name, day, limit, firstConsonant)

	var results []domain.SimilarNameResult
	var step1Results []domain.SimilarNameResult

	// Helper function to build and execute query
	runQuery := func(consonant string, isGeneric bool, ignoreKlakini bool, currentLimit int, currentExcluded []int) ([]domain.SimilarNameResult, error) {
		var query strings.Builder
		args := []interface{}{name} // $1 is always name for similarity
		paramCount := 2

		query.WriteString(fmt.Sprintf(`
			SELECT 
				name_id,
				thname,
				satnum,
				shanum,
				similarity(thname, $1) as sim
			FROM names_miracle
			WHERE 1=1 
		`))

		if !isGeneric {
			// Construct patterns in Go
			p1 := consonant + "%"
			p2 := "เ" + consonant + "%"
			p3 := "แ" + consonant + "%"
			p4 := "โ" + consonant + "%"
			p5 := "ใ" + consonant + "%"
			p6 := "ไ" + consonant + "%"

			args = append(args, p1, p2, p3, p4, p5, p6)

			query.WriteString(fmt.Sprintf(`
				AND (
					thname LIKE $%d OR
					thname LIKE $%d OR
					thname LIKE $%d OR
					thname LIKE $%d OR
					thname LIKE $%d OR
					thname LIKE $%d
				)
			`, paramCount, paramCount+1, paramCount+2, paramCount+3, paramCount+4, paramCount+5))
			paramCount += 6
		}

		if !ignoreKlakini {
			query.WriteString(fmt.Sprintf(" %s ", klakiniWhereClause))
		}

		if len(currentExcluded) > 0 {
			query.WriteString(fmt.Sprintf("AND name_id NOT IN (SELECT unnest($%d::int[])) ", paramCount))
			args = append(args, pq.Array(currentExcluded))
			paramCount++
		}

		query.WriteString(fmt.Sprintf("ORDER BY thname ASC LIMIT %d;", currentLimit))

		return r.executeNameQuery(query.String(), args...)
	}

	// Execute Step 1: Try with strict Klakini rules first
	if firstConsonant != "" {
		var err error
		step1Results, err = runQuery(firstConsonant, false, false, limit, excludedIDs)
		if err != nil {
			return nil, err
		}
		log.Printf("GetFallbackNames Step 1 Found: %d", len(step1Results))
		results = append(results, step1Results...)
	}

	// Step 1.5: If Step 1 found nothing AND we are in strict mode (allowKlakini=false),
	// try to find names with the same consonant BUT ignore Klakini rules.
	// This ensures we at least show some names starting with the correct letter.
	if len(results) == 0 && !allowKlakini && firstConsonant != "" {
		log.Printf("GetFallbackNames Step 1.5: Step 1 empty, trying to find names with consonant '%s' ignoring Klakini...", firstConsonant)

		// We limit this fallback to, say, 20 names, or the full limit, to avoid flooding if there are many.
		// Let's use the full limit for now to fill the list.
		step15Results, err := runQuery(firstConsonant, false, true, limit, excludedIDs) // ignoreKlakini=true
		if err != nil {
			return nil, err
		}
		log.Printf("GetFallbackNames Step 1.5 Found: %d", len(step15Results))
		results = append(results, step15Results...)

		// Add these to excluded for Step 2
		for _, res := range step15Results {
			excludedIDs = append(excludedIDs, res.NameID)
		}
	} else {
		// Add Step 1 results to excluded for Step 2
		for _, res := range step1Results {
			excludedIDs = append(excludedIDs, res.NameID)
		}
	}

	// Step 2: If still not enough results, find other names (any consonant, strict Klakini)
	if len(results) < limit {
		needed := limit - len(results)
		log.Printf("GetFallbackNames Step 2: Found %d, Need %d more. Searching generic...", len(results), needed)

		// Search generic (isGeneric=true), strict Klakini (ignoreKlakini=false)
		step2Results, err := runQuery("", true, false, needed, excludedIDs)
		if err != nil {
			return nil, err
		}
		results = append(results, step2Results...)
	}

	return results, nil
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
		// Add res.Similarity to the Scan
		if err := rows.Scan(&res.NameID, &res.ThName, &satNumStr, &shaNumStr, &res.Similarity); err != nil {
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
