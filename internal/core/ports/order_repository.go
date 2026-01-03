package ports

import "numberniceic/internal/core/domain"

type OrderRepository interface {
	Create(order *domain.Order) error
	GetByRefNo(refNo string) (*domain.Order, error)
	GetByUserID(userID int) ([]domain.Order, error)
	UpdateStatus(refNo string, status string) error
	UpdateRefNo(id uint, newRefNo string) error
	GetAll() ([]domain.Order, error)
	GetWithPagination(limit, offset int, search string) ([]domain.Order, int64, error)
	Delete(id int) error
}
