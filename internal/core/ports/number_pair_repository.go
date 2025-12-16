package ports

import "numberniceic/internal/core/domain"

type NumberPairRepository interface {
	GetAll() ([]domain.NumberPairMeaning, error)
}
