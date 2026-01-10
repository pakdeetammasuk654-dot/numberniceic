package ports

import (
	"numberniceic/internal/core/domain"
	"time"
)

type BuddhistDayRepository interface {
	Create(day *domain.BuddhistDay) error
	GetAll() ([]domain.BuddhistDay, error)
	GetPaginated(offset, limit int) ([]domain.BuddhistDay, int, error)
	Delete(id int) error
	Update(day *domain.BuddhistDay) error
	GetUpcoming(limit int) ([]domain.BuddhistDay, error)
	GetByDate(date time.Time) (*domain.BuddhistDay, error)
}
