package domain

type CategoryBreakdown struct {
	Good        int      `json:"good"`
	Bad         int      `json:"bad"`
	Color       string   `json:"color"`
	Keywords    []string `json:"keywords"`     // Keywords for good pairs
	BadKeywords []string `json:"bad_keywords"` // Keywords for bad pairs
}

type DisplayKeyword struct {
	Text  string `json:"text"`
	IsBad bool   `json:"is_bad"`
}

type AnalysisSummary struct {
	Title           string           `json:"title"`            // e.g., "การงาน การเงิน" or "สุขภาพ"
	Content         []DisplayKeyword `json:"content"`          // Mixed content ready to display
	BackgroundColor string           `json:"background_color"` // Optional: for API usage
	CategoryKey     string           `json:"category_key"`     // e.g. "finance", "work", "health" (for icon mapping)
	IsBad           bool             `json:"is_bad"`
}
