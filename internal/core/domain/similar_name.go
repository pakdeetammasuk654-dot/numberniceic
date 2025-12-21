package domain

// PairTypeInfo holds the type and color for a pair.
type PairTypeInfo struct {
	Type  string `json:"type"`
	Color string `json:"color"`
}

// DisplayChar represents a single character for display, with a flag if it's a klakini.
type DisplayChar struct {
	Char  string
	IsBad bool
}

type SimilarNameResult struct {
	HeaderDisplayNameHTML []DisplayChar  // New field for header rendering with combined consonant+vowel
	NameID                int            `json:"name_id"`
	ThName                string         `json:"th_name"`
	DisplayNameHTML       []DisplayChar  `json:"display_name_html"` // Changed to a slice of DisplayChar
	KlakiniChars          []string       `json:"klakini_chars"`     // New field for Klakini characters
	SatNum                []string       `json:"sat_num"`
	ShaNum                []string       `json:"sha_num"`
	TSat                  []PairTypeInfo `json:"t_sat"`
	TSha                  []PairTypeInfo `json:"t_sha"`
	Distance              float64        `json:"distance"`
	TotalScore            int            `json:"total_score"`
	Similarity            float64        `json:"similarity"`
	IsTopTier             bool           `json:"is_top_tier"`

	// Klakini flags
	KSunday     bool `json:"k_sunday"`
	KMonday     bool `json:"k_monday"`
	KTuesday    bool `json:"k_tuesday"`
	KWednesday1 bool `json:"k_wednesday1"`
	KWednesday2 bool `json:"k_wednesday2"`
	KThursday   bool `json:"k_thursday"`
	KFriday     bool `json:"k_friday"`
	KSaturday   bool `json:"k_saturday"`
}
