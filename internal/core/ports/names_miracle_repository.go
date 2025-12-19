package ports

import "numberniceic/internal/core/domain"

// NamesMiracleRepository defines the port for interacting with the names_miracle data.
type NamesMiracleRepository interface {
	// GetSimilarNames now accepts an allowKlakini flag to conditionally filter.
	GetSimilarNames(name, day string, limit, offset int, allowKlakini bool) ([]domain.SimilarNameResult, error)
	GetAuspiciousNames(name, preferredConsonant, day string, limit, offset int, allowKlakini bool) ([]domain.SimilarNameResult, error)
	GetFallbackNames(name, preferredConsonant, day string, limit int, allowKlakini bool, excludedIDs []int) ([]domain.SimilarNameResult, error)
}
