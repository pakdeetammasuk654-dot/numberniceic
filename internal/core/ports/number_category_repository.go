package ports

import "numberniceic/internal/core/domain"

type NumberCategoryRepository interface {
	GetAll() ([]domain.NumberCategory, error)
}
