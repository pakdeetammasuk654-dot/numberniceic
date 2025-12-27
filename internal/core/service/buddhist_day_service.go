package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type BuddhistDayService struct {
	repo ports.BuddhistDayRepository
}

func NewBuddhistDayService(repo ports.BuddhistDayRepository) *BuddhistDayService {
	return &BuddhistDayService{repo: repo}
}

func (s *BuddhistDayService) AddDay(dateStr string) error {
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return err
	}
	return s.repo.Create(date)
}

func (s *BuddhistDayService) GetAllDays() ([]domain.BuddhistDay, error) {
	return s.repo.GetAll()
}

func (s *BuddhistDayService) DeleteDay(id int) error {
	return s.repo.Delete(id)
}

func (s *BuddhistDayService) GetUpcomingDays(limit int) ([]domain.BuddhistDay, error) {
	return s.repo.GetUpcoming(limit)
}

func (s *BuddhistDayService) IsBuddhistDay(date time.Time) (bool, error) {
	// Truncate to midnight safely respecting the timezone of 'date'
	// time.Truncate(24h) truncates to UTC midnight, which is wrong for +0700
	truncated := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())

	day, err := s.repo.GetByDate(truncated)
	if err != nil {
		return false, err
	}
	return day != nil, nil
}
