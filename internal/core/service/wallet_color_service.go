package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type WalletColorService struct {
	repo ports.WalletColorRepository
}

func NewWalletColorService(repo ports.WalletColorRepository) *WalletColorService {
	return &WalletColorService{repo: repo}
}

func (s *WalletColorService) GetAll() ([]domain.WalletColor, error) {
	return s.repo.GetAll()
}

func (s *WalletColorService) Update(color *domain.WalletColor) error {
	return s.repo.Update(color)
}

func (s *WalletColorService) GetByDay(dayOfWeek int) (*domain.WalletColor, error) {
	return s.repo.GetByDay(dayOfWeek)
}
