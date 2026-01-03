package ports

import "numberniceic/internal/core/domain"

type ShippingAddressRepository interface {
	Create(address *domain.ShippingAddress) error
	GetByUserID(userID int) ([]domain.ShippingAddress, error)
	GetDefaultByUserID(userID int) (*domain.ShippingAddress, error)
	Update(address *domain.ShippingAddress) error
	Delete(id int) error
}
