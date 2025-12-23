package ports

import "numberniceic/internal/core/domain"

type SampleNamesRepository interface {
	GetAll() ([]domain.SampleName, error)
	SetActive(id int) error
}
