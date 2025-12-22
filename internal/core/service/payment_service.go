package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type PaymentService struct {
	orderRepo  ports.OrderRepository
	memberRepo ports.MemberRepository // To upgrade user status
}

func NewPaymentService(orderRepo ports.OrderRepository, memberRepo ports.MemberRepository) *PaymentService {
	return &PaymentService{
		orderRepo:  orderRepo,
		memberRepo: memberRepo,
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

	// 2. Validate Amount
	// In production, check if amountPaid >= order.Amount

	// 3. Update Order Status
	err = s.orderRepo.UpdateStatus(refNo, "paid")
	if err != nil {
		return err
	}

	// 4. Grant VIP Status if UserID is present
	if order.UserID != nil {
		// Use MemberRepository to set VIP status
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
