package ports

import "numberniceic/internal/core/domain"

type KlakiniRepository interface {
	GetAll() ([]domain.Klakini, error)
}
