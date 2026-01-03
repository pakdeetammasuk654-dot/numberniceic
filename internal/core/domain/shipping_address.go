package domain

import "time"

type ShippingAddress struct {
	ID            int       `json:"id" db:"id"`
	UserID        int       `json:"user_id" db:"user_id"`
	RecipientName string    `json:"recipient_name" db:"recipient_name"`
	PhoneNumber   string    `json:"phone_number" db:"phone_number"`
	AddressLine1  string    `json:"address_line1" db:"address_line1"`
	SubDistrict   string    `json:"sub_district" db:"sub_district"`
	District      string    `json:"district" db:"district"`
	Province      string    `json:"province" db:"province"`
	PostalCode    string    `json:"postal_code" db:"postal_code"`
	IsDefault     bool      `json:"is_default" db:"is_default"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}
