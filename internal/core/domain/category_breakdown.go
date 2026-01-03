package domain

type CategoryBreakdown struct {
	Good     int      `json:"good"`
	Bad      int      `json:"bad"`
	Color    string   `json:"color"`
	Keywords []string `json:"keywords"`
}
