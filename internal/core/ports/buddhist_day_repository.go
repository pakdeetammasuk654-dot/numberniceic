package ports

import (
	"numberniceic/internal/core/domain"
	"time"
)

type BuddhistDayRepository interface {
	Create(date time.Time) error
	GetAll() ([]domain.BuddhistDay, error)
	Delete(id int) error
	GetUpcoming(limit int) ([]domain.BuddhistDay, error)
	GetByDate(date time.Time) (*domain.BuddhistDay, error)
}
