package ports

import "numberniceic/internal/core/domain"

type MemberRepository interface {
	Create(member *domain.Member) error
	GetByUsername(username string) (*domain.Member, error)
	GetByEmail(email string) (*domain.Member, error)
	GetByID(id int) (*domain.Member, error)
	GetByProvider(provider, providerID string) (*domain.Member, error)
	Update(member *domain.Member) error
	Delete(id int) error

	UpdateDayOfBirth(id int, dayOfWeek int) error

	// Admin methods
	GetAllMembers() ([]domain.Member, error)
	UpdateStatus(id int, status int) error
	SetVIP(id int, isVIP bool) error
	SetVIPWithExpiry(id int, duration string) error
	UpdateAssignedColors(id int, colors string) error
	GetMembersWithAssignedColors() ([]domain.Member, error)
	CreateNotification(userID int, title, message string) error
	CreateBroadcastNotification(title, message string) error
}
