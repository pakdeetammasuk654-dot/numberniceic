package domain

import "time"

type PromotionalCode struct {
	ID             int        `json:"id"`
	Code           string     `json:"code"`
	IsUsed         bool       `json:"is_used"`
	UsedByMemberID *int       `json:"used_by_member_id"`
	UsedAt         *time.Time `json:"used_at"`
	CreatedAt      time.Time  `json:"created_at"`
	OwnerMemberID  *int       `json:"owner_member_id"`
	ProductName    string     `json:"product_name"`
}
