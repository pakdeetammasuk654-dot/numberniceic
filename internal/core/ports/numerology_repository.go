package ports

import "numberniceic/internal/core/domain"

// NumerologyRepository defines the port for accessing numerology-style data (e.g., Sat Num, Sha Num).
// It's a generic interface for fetching character-to-value mappings.
type NumerologyRepository interface {
	GetAll() ([]domain.Numerology, error)
}
