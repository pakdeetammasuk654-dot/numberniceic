package domain

type SampleName struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	AvatarURL string `json:"avatar_url"`
	IsActive  bool   `json:"is_active"`
}
