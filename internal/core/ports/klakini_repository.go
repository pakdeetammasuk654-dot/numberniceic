package ports

import "numberniceic/internal/core/domain"

type KlakiniRepository interface {
	GetAll() ([]domain.Klakini, error)
	GetByDay(day string) (domain.Klakini, error)
}
