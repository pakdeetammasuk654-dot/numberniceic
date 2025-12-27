package ports

import "numberniceic/internal/core/domain"

type WalletColorRepository interface {
	GetAll() ([]domain.WalletColor, error)
	GetByDay(dayOfWeek int) (*domain.WalletColor, error)
	Update(color *domain.WalletColor) error
}
