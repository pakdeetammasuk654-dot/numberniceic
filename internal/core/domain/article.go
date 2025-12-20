package domain

import "time"

type Article struct {
	ID          int       `json:"art_id"`
	Slug        string    `json:"slug"`
	Title       string    `json:"title"`
	Excerpt     string    `json:"excerpt"`
	Category    string    `json:"category"`
	ImageURL    string    `json:"image_url"`
	PublishedAt time.Time `json:"published_at"`
	IsPublished bool      `json:"is_published"`
	Content     string    `json:"content"`
	TitleShort  string    `json:"title_short"`
}
