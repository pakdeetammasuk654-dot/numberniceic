package domain

import "time"

type SavedName struct {
	ID         int        `json:"id"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	DeletedAt  *time.Time `json:"deleted_at"`
	UserID     int        `json:"user_id"`
	Name       string     `json:"name"`
	BirthDay   string     `json:"birth_day"`
	TotalScore int        `json:"total_score"`
	SatSum     int        `json:"sat_sum"`
	ShaSum     int        `json:"sha_sum"`
}

type SavedNameDisplay struct {
	SavedName
	BirthDayThai    string        `json:"birth_day_thai"`
	BirthDayRaw     string        `json:"birth_day_raw"`
	KlakiniChars    []string      `json:"klakini_chars"`
	SatPairs        []PairInfo    `json:"sat_pairs"`
	ShaPairs        []PairInfo    `json:"sha_pairs"`
	DisplayNameHTML []DisplayChar `json:"display_name_html"`
	IsTopTier       bool          `json:"is_top_tier"`
}

type PairInfo struct {
	Number string
	Color  string
}
