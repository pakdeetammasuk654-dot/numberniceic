package ports

import "numberniceic/internal/core/domain"

type PhoneNumberRepository interface {
	GetAll() ([]domain.PhoneNumberSell, error)
	GetPaged(offset, limit int) ([]domain.PhoneNumberSell, error)
	Count() (int, error)
	GetByPrefix(prefix string) ([]domain.PhoneNumberSell, error)
}
