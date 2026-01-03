package domain

import "time"

type Product struct {
	ID          int       `json:"id"`
	Code        string    `json:"code"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Price       int       `json:"price"`
	ImagePath   string    `json:"image_path"`
	IconType    string    `json:"icon_type"`
	ImageColor1 string    `json:"image_color_1"`
	ImageColor2 string    `json:"image_color_2"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}
