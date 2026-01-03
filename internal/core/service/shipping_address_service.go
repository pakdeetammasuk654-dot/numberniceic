package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type ShippingAddressService struct {
	repo ports.ShippingAddressRepository
}

func NewShippingAddressService(repo ports.ShippingAddressRepository) *ShippingAddressService {
	return &ShippingAddressService{repo: repo}
}

func (s *ShippingAddressService) AddAddress(address *domain.ShippingAddress) error {
	// Logic: If user has no addresses, make this default.
	existing, err := s.repo.GetByUserID(address.UserID)
	if err == nil && len(existing) == 0 {
		address.IsDefault = true
	}
	// If explicit default is set, unset others? (Complexity reduced for now, just simple add)
	// Ideally we unset other defaults if this is set to default. Not implemented for brevity.

	return s.repo.Create(address)
}

func (s *ShippingAddressService) GetMyAddresses(userID int) ([]domain.ShippingAddress, error) {
	return s.repo.GetByUserID(userID)
}

func (s *ShippingAddressService) GetMyDefaultAddress(userID int) (*domain.ShippingAddress, error) {
	return s.repo.GetDefaultByUserID(userID)
}

func (s *ShippingAddressService) UpdateAddress(address *domain.ShippingAddress) error {
	return s.repo.Update(address)
}

func (s *ShippingAddressService) DeleteAddress(id int) error {
	return s.repo.Delete(id)
}
