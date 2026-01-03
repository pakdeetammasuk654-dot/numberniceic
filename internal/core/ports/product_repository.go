package ports

import "numberniceic/internal/core/domain"

type ProductRepository interface {
	GetAll() ([]domain.Product, error)
	GetByID(id int) (*domain.Product, error)
	GetByCode(code string) (*domain.Product, error)
	Create(product *domain.Product) error
	Update(product *domain.Product) error
	Delete(id int) error
}
