package ports

import "numberniceic/internal/core/domain"

type SavedNameRepository interface {
	Save(savedName *domain.SavedName) error
	GetByUserID(userID int) ([]domain.SavedName, error)
	Delete(id int, userID int) error
}
