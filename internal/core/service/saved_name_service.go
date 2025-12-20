package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type SavedNameService struct {
	repo ports.SavedNameRepository
}

func NewSavedNameService(repo ports.SavedNameRepository) *SavedNameService {
	return &SavedNameService{repo: repo}
}

func (s *SavedNameService) SaveName(userID int, name, birthDay string, totalScore, satSum, shaSum int) error {
	savedName := &domain.SavedName{
		UserID:     userID,
		Name:       name,
		BirthDay:   birthDay,
		TotalScore: totalScore,
		SatSum:     satSum,
		ShaSum:     shaSum,
	}
	return s.repo.Save(savedName)
}

func (s *SavedNameService) GetSavedNames(userID int) ([]domain.SavedName, error) {
	return s.repo.GetByUserID(userID)
}

func (s *SavedNameService) DeleteSavedName(id int, userID int) error {
	return s.repo.Delete(id, userID)
}
