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
            WHERE similarity(thname, $1) > 0.01 -- Keep this for the "similar" search
        )
        SELECT 
            name_id,
            thname,
            satnum,
            shanum,
            sim -- Return the similarity score
        FROM ranked_names
        ORDER BY (CASE WHEN thname = $1 THEN 1 ELSE 0 END) DESC, sim DESC, thname ASC
        LIMIT $2 OFFSET $3;
    `, klakiniWhereClause)

	return r.executeNameQuery(query, name, limit, offset)
}

// GetBestSimilarNames fetches highly similar names that are also "Top Tier" (Strictly Good Pairs).
// This avoids the need to iterate through thousands of names in the application layer.
func (r *PostgresNamesMiracleRepository) GetBestSimilarNames(name, day string, limit int, allowKlakini bool) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	// Build the WHERE clause for Klakini
	klakiniWhereClause := ""
	if !allowKlakini {
		klakiniWhereClause = fmt.Sprintf("AND %s = false", klakiniColumn)
	}

	// Filter for Strict Good Pairs: t_sat and t_sha must ONLY contain D10, D8, D5
	// Using PostgreSQL array containment operator <@
	// e.g. t_sat <@ ARRAY['D10', 'D8', 'D5']::text[]
	strictGoodClause := `
		AND t_sat <@ ARRAY['D10', 'D8', 'D5']::text[]
		AND t_sha <@ ARRAY['D10', 'D8', 'D5']::text[]
	`

	query := fmt.Sprintf(`
        SELECT 
            name_id,
            thname,
            satnum,
            shanum,
            similarity(thname, $1) as sim
        FROM names_miracle
        WHERE 1=1 
		%s 
		%s
		AND similarity(thname, $1) > 0.001 -- Lower threshold to ensure we find *something*, but still relevant
        ORDER BY sim DESC, thname ASC
        LIMIT $2;
    `, klakiniWhereClause, strictGoodClause)

	return r.executeNameQuery(query, name, limit)
}

// GetAuspiciousNames fetches names for the auspicious search, which has different filtering rules.
func (r *PostgresNamesMiracleRepository) GetAuspiciousNames(name, preferredConsonant, day string, limit, offset int, allowKlakini, findGoodOnly bool) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	// Build the WHERE clause
	filters := []string{"1=1"}
	if !allowKlakini {
		filters = append(filters, fmt.Sprintf("%s = false", klakiniColumn))
	}

	if findGoodOnly {
		// Only Good Pairs: t_sat and t_sha must NOT contain R10, R7, R5
		filters = append(filters, "NOT (t_sat && ARRAY['R10', 'R7', 'R5']::text[])")
		filters = append(filters, "NOT (t_sha && ARRAY['R10', 'R7', 'R5']::text[])")
	}

	orderBy := "ORDER BY sim DESC"
	args := []interface{}{name} // $1
	paramCount := 1

	if preferredConsonant != "" {
		p1 := preferredConsonant + "%"
		p2 := "เ" + preferredConsonant + "%"
		p3 := "แ" + preferredConsonant + "%"
		p4 := "โ" + preferredConsonant + "%"
		p5 := "ใ" + preferredConsonant + "%"
		p6 := "ไ" + preferredConsonant + "%"

		args = append(args, p1, p2, p3, p4, p5, p6)

		// Prioritize names starting with the same consonant (including leading vowels)
		orderBy = fmt.Sprintf(`ORDER BY (
			CASE 
				WHEN thname LIKE $%d THEN 1
				WHEN thname LIKE $%d THEN 1
				WHEN thname LIKE $%d THEN 1
				WHEN thname LIKE $%d THEN 1
				WHEN thname LIKE $%d THEN 1
				WHEN thname LIKE $%d THEN 1
				ELSE 0 
			END
		) DESC, sim DESC`, paramCount+1, paramCount+2, paramCount+3, paramCount+4, paramCount+5, paramCount+6)

		paramCount += 6
	}

	args = append(args, limit, offset)
	limitIdx := paramCount + 1
	offsetIdx := paramCount + 2

	query := fmt.Sprintf(`
        WITH filtered_names AS (
            SELECT 
                name_id,
                thname,
                satnum,
                shanum
            FROM names_miracle
            WHERE %s
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
            sim
        FROM ranked_names
        %s
        LIMIT $%d OFFSET $%d;
    `, strings.Join(filters, " AND "), orderBy, limitIdx, offsetIdx)

	return r.executeNameQuery(query, args...)
}

func (r *PostgresNamesMiracleRepository) GetFallbackNames(name, preferredConsonant, day string, limit int, allowKlakini bool, excludedIDs []int) ([]domain.SimilarNameResult, error) {
	klakiniColumn, err := getKlakiniColumn(day)
	if err != nil {
		return nil, err
	}

	klakiniWhereClause := ""
	if !allowKlakini {
		klakiniWhereClause = fmt.Sprintf("AND %s = false", klakiniColumn)
	}

	log.Printf("GetFallbackNames Step 1: name=%s, day=%s, limit=%d, consonant=%s", name, day, limit, preferredConsonant)

	var results []domain.SimilarNameResult
	var step1Results []domain.SimilarNameResult

	// Helper function to build and execute query
	runQuery := func(consonant string, isGeneric bool, ignoreKlakini bool, currentLimit int, currentExcluded []int) ([]domain.SimilarNameResult, error) {
		var query strings.Builder
		args := []interface{}{name} // $1 is always name for similarity
		paramCount := 2

		query.WriteString(`
			SELECT 
				name_id,
				thname,
				satnum,
				shanum,
				similarity(thname, $1) as sim
			FROM names_miracle
			WHERE 1=1 
		`)

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
			query.WriteString(fmt.Sprintf("AND name_id NOT IN (SELECT unnest($%d::bigint[])) ", paramCount))
			args = append(args, pq.Array(currentExcluded))
			paramCount++
		}

		query.WriteString(fmt.Sprintf("ORDER BY thname ASC LIMIT %d;", currentLimit))

		return r.executeNameQuery(query.String(), args...)
	}

	// Execute Step 1: Try with strict Klakini rules first
	if preferredConsonant != "" {
		var err error
		step1Results, err = runQuery(preferredConsonant, false, false, limit, excludedIDs)
		if err != nil {
			return nil, err
		}
		log.Printf("GetFallbackNames Step 1 Found: %d", len(step1Results))
		results = append(results, step1Results...)
	}

	// Step 1.5: If Step 1 found nothing AND we are in strict mode (allowKlakini=false),
	// try to find names with the same consonant BUT ignore Klakini rules.
	// This ensures we at least show some names starting with the correct letter.
	if len(results) == 0 && !allowKlakini && preferredConsonant != "" {
		log.Printf("GetFallbackNames Step 1.5: Step 1 empty, trying to find names with consonant '%s' ignoring Klakini...", preferredConsonant)

		step15Results, err := runQuery(preferredConsonant, false, true, limit, excludedIDs) // ignoreKlakini=true
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

	// Step 2: Adaptive Wrap-Around Backfill
	if len(results) < limit {
		needed := limit - len(results)
		log.Printf("GetFallbackNames Step 2: Found %d, Need %d more. Starting wrap-around search from '%s'...", len(results), needed, preferredConsonant)

		// Prepare excluded IDs for SQL array
		currentExcluded := make([]int, len(excludedIDs))
		copy(currentExcluded, excludedIDs)
		// Add currently found names to exclusion too, to be safe
		for _, r := range results {
			// Check if already in excluded to avoid dupes?
			// Simpler to just let postgres handle "NOT IN" with a big array,
			// or append new IDs to currentExcluded.
			// Ideally excludedIDs is cumulative.
			currentExcluded = append(currentExcluded, r.NameID)
		}

		pivot := preferredConsonant
		if pivot == "" {
			pivot = "ก"
		}

		// Helper to run raw query for Step 2a/2b
		runRaw := func(compareOp string, currentLimit int) ([]domain.SimilarNameResult, error) {
			// $1=name (for sim calc cache), $2=pivot, $3=limit, $4=excluded
			q := fmt.Sprintf(`
				SELECT 
					name_id, thname, satnum, shanum, similarity(thname, $1) as sim
				FROM names_miracle
				WHERE thname %s $2
				%s -- klakini check
				AND name_id NOT IN (SELECT unnest($3::bigint[]))
				ORDER BY thname ASC
				LIMIT $4;
			`, compareOp, klakiniWhereClause)

			// Args: name, pivot, excluded, limit
			// Wait, postgres driver args matching?
			// SELECT... similarity(thname, $1) ... WHERE thname >= $2 ... unnest($3) ... LIMIT $4
			return r.executeNameQuery(q, name, pivot, pq.Array(currentExcluded), currentLimit)
		}

		// Step 2a: From Pivot to End (thname >= pivot)
		step2aResults, err := runRaw(">=", needed)
		if err != nil {
			return nil, err
		}
		results = append(results, step2aResults...)

		// Update needed count
		needed -= len(step2aResults)

		// Step 2b: From Start to Pivot (thname < pivot) - Wrap around
		if needed > 0 {
			// Update excluded IDs with Step 2a results
			for _, res := range step2aResults {
				currentExcluded = append(currentExcluded, res.NameID)
			}

			log.Printf("GetFallbackNames Step 2b: Wrapping around to start... Need %d more.", needed)
			step2bResults, err := runRaw("<", needed)
			if err != nil {
				return nil, err
			}
			results = append(results, step2bResults...)
		}
	}

	return results, nil
}

func (r *PostgresNamesMiracleRepository) Create(name *domain.SimilarNameResult) error {
	// Prepare t_sat and t_sha strings for pq.Array
	var tSat []string
	for _, t := range name.TSat {
		tSat = append(tSat, t.Type)
	}
	var tSha []string
	for _, t := range name.TSha {
		tSha = append(tSha, t.Type)
	}

	query := `
		INSERT INTO names_miracle (
			thname, satnum, shanum, 
			k_sunday, k_monday, k_tuesday, k_wednesday1, k_wednesday2, k_thursday, k_friday, k_saturday,
			t_sat, t_sha
		) VALUES (
			$1, $2, $3, 
			$4, $5, $6, $7, $8, $9, $10, $11,
			$12, $13
		) RETURNING name_id
	`
	err := r.db.QueryRow(
		query,
		name.ThName,
		pq.Array(name.SatNum),
		pq.Array(name.ShaNum),
		name.KSunday,
		name.KMonday,
		name.KTuesday,
		name.KWednesday1,
		name.KWednesday2,
		name.KThursday,
		name.KFriday,
		name.KSaturday,
		pq.Array(tSat),
		pq.Array(tSha),
	).Scan(&name.NameID)

	return err
}

func (r *PostgresNamesMiracleRepository) GetLatest(limit int) ([]domain.SimilarNameResult, error) {
	query := `
		SELECT 
			name_id, thname, satnum, shanum,
			k_sunday, k_monday, k_tuesday, k_wednesday1, k_wednesday2, k_thursday, k_friday, k_saturday,
			t_sat, t_sha
		FROM names_miracle
		ORDER BY name_id DESC
		LIMIT $1
	`
	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []domain.SimilarNameResult
	for rows.Next() {
		var res domain.SimilarNameResult
		var satNum, shaNum, tSat, tSha pq.StringArray
		err := rows.Scan(
			&res.NameID, &res.ThName, &satNum, &shaNum,
			&res.KSunday, &res.KMonday, &res.KTuesday, &res.KWednesday1, &res.KWednesday2, &res.KThursday, &res.KFriday, &res.KSaturday,
			&tSat, &tSha,
		)
		if err != nil {
			return nil, err
		}

		res.SatNum = []string(satNum)
		res.ShaNum = []string(shaNum)

		res.TSat = make([]domain.PairTypeInfo, len(tSat))
		for i, v := range tSat {
			res.TSat[i] = domain.PairTypeInfo{Type: v}
		}
		res.TSha = make([]domain.PairTypeInfo, len(tSha))
		for i, v := range tSha {
			res.TSha[i] = domain.PairTypeInfo{Type: v}
		}

		results = append(results, res)
	}
	return results, nil
}

func (r *PostgresNamesMiracleRepository) Delete(id int) error {
	query := "DELETE FROM names_miracle WHERE name_id = $1"
	_, err := r.db.Exec(query, id)
	return err
}

func (r *PostgresNamesMiracleRepository) Count() (int, error) {
	var count int
	query := "SELECT COUNT(*) FROM names_miracle"
	err := r.db.QueryRow(query).Scan(&count)
	return count, err
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
