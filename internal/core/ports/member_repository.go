package ports

import "numberniceic/internal/core/domain"

type MemberRepository interface {
	Create(member *domain.Member) error
	GetByUsername(username string) (*domain.Member, error)
	GetByEmail(email string) (*domain.Member, error)
	GetByID(id int) (*domain.Member, error)
	Update(member *domain.Member) error
	Delete(id int) error
	CheckPassword(hashedPassword, password string) error

	// Admin methods
	GetAllMembers() ([]domain.Member, error)
	UpdateStatus(id int, status int) error
	SetVIP(id int, isVIP bool) error
}
