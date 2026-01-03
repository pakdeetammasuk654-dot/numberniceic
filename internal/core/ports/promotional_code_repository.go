package ports

import "numberniceic/internal/core/domain"

type PromotionalCodeRepository interface {
	CreatePurchase(code string, ownerID int, productName string) error
	GetByCode(code string) (*domain.PromotionalCode, error)
	Redeem(codeID int, memberID int) error
	GetByOwnerID(ownerID int) ([]domain.PromotionalCode, error)
	GenerateCode(code string) error
}
