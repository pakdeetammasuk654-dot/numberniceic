package service

import (
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/domain"
)

type MobileConfigService struct {
	repo *repository.PostgresMobileConfigRepository
}

func NewMobileConfigService(repo *repository.PostgresMobileConfigRepository) *MobileConfigService {
	return &MobileConfigService{repo: repo}
}

func (s *MobileConfigService) GetWelcomeMessage() (*domain.MobileWelcomeConfig, error) {
	return s.repo.GetLatestWelcomeConfig()
}

func (s *MobileConfigService) UpdateWelcomeMessage(title, body string, isActive bool) error {
	return s.repo.UpdateWelcomeConfig(title, body, isActive)
}
