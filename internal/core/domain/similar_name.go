package domain

// PairTypeInfo holds the type and color for a pair.
type PairTypeInfo struct {
	Type  string `json:"type"`
	Color string `json:"color"`
}

type SimilarNameResult struct {
	NameID     int            `json:"name_id"`
	ThName     string         `json:"th_name"`
	SatNum     []string       `json:"sat_num"`
	ShaNum     []string       `json:"sha_num"`
	TSat       []PairTypeInfo `json:"t_sat"` // Changed to a struct
	TSha       []PairTypeInfo `json:"t_sha"` // Changed to a struct
	Distance   float64        `json:"distance"`
	TotalScore int            `json:"total_score"`

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
