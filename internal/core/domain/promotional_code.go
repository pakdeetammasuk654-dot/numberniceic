package domain

import "time"

type PromotionalCode struct {
	ID                       int        `json:"id"`
	Code                     string     `json:"code"`
	IsUsed                   bool       `json:"is_used"`
	UsedByMemberID           *int       `json:"used_by_member_id"`
	UsedByMemberName         string     `json:"used_by_member_name"`
	UsedByMemberAvatar       string     `json:"used_by_member_avatar"`
	UsedByMemberStatus       int        `json:"used_by_member_status"`
	UsedByMemberVIPExpiresAt *time.Time `json:"used_by_member_vip_expires_at"`
	UsedAt                   *time.Time `json:"used_at"`
	CreatedAt                time.Time  `json:"created_at"`
	OwnerMemberID            *int       `json:"owner_member_id"`
	OwnerMemberName          string     `json:"owner_member_name"`
	OwnerMemberAvatar        string     `json:"owner_member_avatar"`
	OwnerMemberStatus        int        `json:"owner_member_status"`
	OwnerMemberVIPExpiresAt  *time.Time `json:"owner_member_vip_expires_at"`
	ProductName              string     `json:"product_name"`
}
