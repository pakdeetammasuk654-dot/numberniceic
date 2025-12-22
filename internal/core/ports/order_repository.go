package ports

import "numberniceic/internal/core/domain"

type OrderRepository interface {
	Create(order *domain.Order) error
	GetByRefNo(refNo string) (*domain.Order, error)
	UpdateStatus(refNo string, status string) error
}
