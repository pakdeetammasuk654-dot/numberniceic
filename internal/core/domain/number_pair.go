package domain

type NumberPairMeaning struct {
	PairNumber    string   `json:"pair_number"`
	PairType      string   `json:"pair_type"`
	MiracleDetail string   `json:"miracle_detail"`
	MiracleDesc   string   `json:"miracle_desc"`
	PairPoint     int      `json:"pair_point"`
	Color         string   `json:"color"`    // New field for color
	Category      string   `json:"category"` // Added for filtering lucky numbers
	Keywords      []string `json:"keywords"` // Added for display
	IsBad         bool     `json:"is_bad"`   // Added for UI logic
}

type NumberCategory struct {
	PairNumber string   `json:"pair_number"`
	Category   string   `json:"category"`
	NumberType string   `json:"number_type"` // ดี or ร้าย
	Keywords   []string `json:"keywords"`
}
