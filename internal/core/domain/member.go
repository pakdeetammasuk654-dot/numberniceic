package domain

import (
	"fmt"
	"time"
)

type Member struct {
	ID       int    `json:"id"`
	Username string `json:"username"`

	Provider               string     `json:"provider"`    // "line", "facebook", "google"
	ProviderID             string     `json:"provider_id"` // Unique ID from provider
	Email                  string     `json:"email"`
	AvatarURL              string     `json:"avatar_url"`
	Tel                    string     `json:"tel"`
	Status                 int        `json:"status"`
	DayOfBirth             *int       `json:"day_of_birth"` // 0=Sunday, 1=Monday, ..., 6=Saturday
	AssignedColors         string     `json:"assigned_colors"`
	VIPExpiresAt           *time.Time `json:"vip_expires_at"`
	WalletColorsNotifiedAt *time.Time `json:"wallet_colors_notified_at"` // New: tracked for notification status
	CreatedAt              time.Time  `json:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at"`
	DeletedAt              *time.Time `json:"deleted_at"`
}

const (
	// Status Constants
	StatusBanned = -1
	StatusMember = 1
	StatusVIP    = 2
)

func (m *Member) IsVIP() bool {
	if m == nil {
		return false
	}
	if m.Status != StatusVIP && m.Status != 9 {
		return false
	}

	// If VIPExpiresAt is not set, assume lifetime VIP (backward compatibility)
	if m.VIPExpiresAt == nil {
		return true
	}

	// Check if VIP has expired
	return time.Now().Before(*m.VIPExpiresAt)
}

// GetVIPDaysRemaining returns the number of days remaining for VIP membership
// Returns -1 if expired, 0 if not VIP
func (m *Member) GetVIPDaysRemaining() int {
	if m == nil {
		return 0
	}
	if m.Status != StatusVIP && m.Status != 9 {
		return 0
	}

	if m.VIPExpiresAt == nil {
		return 999999 // Lifetime VIP
	}

	days := int(time.Until(*m.VIPExpiresAt).Hours() / 24)
	if days < 0 {
		return -1 // Expired
	}
	return days
}

// GetVIPExpiryText returns a human-readable text for VIP expiry status
func (m *Member) GetVIPExpiryText() string {
	if m == nil {
		return ""
	}
	if m.Status != StatusVIP && m.Status != 9 {
		return ""
	}

	if m.Status == 9 {
		return "ผู้ดูแลระบบ"
	}

	if m.VIPExpiresAt == nil {
		return "ตลอดชีพ"
	}

	days := m.GetVIPDaysRemaining()
	if days < 0 {
		return "หมดอายุแล้ว"
	}

	if days == 0 {
		return "หมดอายุวันนี้"
	}

	if days <= 30 {
		return fmt.Sprintf("เหลืออีก %d วัน", days)
	}

	months := days / 30
	if months == 1 {
		return "เหลืออีก 1 เดือน"
	}

	if months < 12 {
		return fmt.Sprintf("เหลืออีก %d เดือน", months)
	}

	years := months / 12
	remainingMonths := months % 12
	if remainingMonths == 0 {
		if years == 1 {
			return "เหลืออีก 1 ปี"
		}
		return fmt.Sprintf("เหลืออีก %d ปี", years)
	}

	if years == 1 {
		return fmt.Sprintf("เหลืออีก 1 ปี %d เดือน", remainingMonths)
	}

	return fmt.Sprintf("เหลืออีก %d ปี %d เดือน", years, remainingMonths)
}
