package ports

import "numberniceic/internal/core/domain"

// NamesMiracleRepository defines the port for interacting with the names_miracle data.
type NamesMiracleRepository interface {
	GetSimilarNames(name, day string, limit, offset int) ([]domain.SimilarNameResult, error)
	GetAuspiciousNames(name, day string, limit, offset int) ([]domain.SimilarNameResult, error)
}
