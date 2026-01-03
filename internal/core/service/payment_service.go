package service

import (
	"fmt"
	"math/rand"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"

	"github.com/google/uuid"
)

type PaymentService struct {
	orderRepo  ports.OrderRepository
	memberRepo ports.MemberRepository // To upgrade user status
	promoRepo  ports.PromotionalCodeRepository
}

func NewPaymentService(orderRepo ports.OrderRepository, memberRepo ports.MemberRepository, promoRepo ports.PromotionalCodeRepository) *PaymentService {
	return &PaymentService{
		orderRepo:  orderRepo,
		memberRepo: memberRepo,
		promoRepo:  promoRepo,
	}
}

func (s *PaymentService) CreateOrder(refNo string, amount float64, userID *int) error {
	order := &domain.Order{
		RefNo:  refNo,
		Amount: amount,
		UserID: userID,
		Status: "pending",
	}
	return s.orderRepo.Create(order)
}

func (s *PaymentService) ProcessPaymentSuccess(refNo string, amountPaid float64) error {
	// 1. Get Order
	order, err := s.orderRepo.GetByRefNo(refNo)
	if err != nil {
		return err
	}

	// 2. Validate Amount (Optional Check)
	// if amountPaid < order.Amount { ... }

	// 3. Update Order Status
	err = s.orderRepo.UpdateStatus(refNo, "paid")
	if err != nil {
		return err
	}

	// 4. If Shop Order (has ProductName), Generate VIP Code
	if order.ProductName != "" {
		vipCode := fmt.Sprintf("VIP-%s-%d", uuid.New().String()[0:4], rand.Intn(9999))
		ownerID := 0
		if order.UserID != nil {
			ownerID = *order.UserID
		}

		// Create Purchase (Save Code)
		// Assuming ports.PromotionalCodeRepository interface matches Postgres implementation
		// We might need to confirm interface methods. Use CreatePurchase.
		err = s.promoRepo.CreatePurchase(vipCode, ownerID, order.ProductName)
		if err != nil {
			return err
		}
	}

	// 5. Grant VIP Status if UserID is present (Legacy & Shop)
	if order.UserID != nil {
		err = s.memberRepo.SetVIP(*order.UserID, true)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *PaymentService) GetOrder(refNo string) (*domain.Order, error) {
	return s.orderRepo.GetByRefNo(refNo)
}
