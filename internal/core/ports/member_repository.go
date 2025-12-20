package ports

import "numberniceic/internal/core/domain"

// MemberRepository defines the interface for interacting with member data.
type MemberRepository interface {
	Create(member *domain.Member) error
	FindByUsername(username string) (*domain.Member, error)
	FindByID(id int) (*domain.Member, error)
}
