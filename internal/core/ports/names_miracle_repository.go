package ports

import "numberniceic/internal/core/domain"

type NamesMiracleRepository interface {
	GetSimilarNames(name, day string, limit int) ([]domain.SimilarNameResult, error)
	GetAuspiciousNames(name, day string, limit int) ([]domain.SimilarNameResult, error)
}
