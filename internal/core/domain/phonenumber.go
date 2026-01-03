package domain

type PhoneNumberSell struct {
	PNumberID       int    `json:"pnumber_id"`
	PNumberPosition int    `json:"pnumber_position"`
	PNumberNum      string `json:"pnumber_num"`
	PNumberSum      string `json:"pnumber_sum"`
	PNumberPrice    int    `json:"pnumber_price"`
	PhoneGroup      string `json:"phone_group"`
	SellStatus      string `json:"sell_status"`
	PrefixGroup     string `json:"prefix_group"`
}

type PhoneNumberPairMeaning struct {
	Pair    string            `json:"pair"`
	Meaning NumberPairMeaning `json:"meaning"`
}

type PhoneNumberAnalysis struct {
	PhoneNumber    PhoneNumberSell          `json:"phone_number"`
	PrimaryPairs   []PhoneNumberPairMeaning `json:"primary_pairs"`
	SecondaryPairs []PhoneNumberPairMeaning `json:"secondary_pairs"`
	SumMeaning     NumberPairMeaning        `json:"sum_meaning"`
	TotalScore     int                      `json:"total_score"`
}
type PagedPhoneNumberAnalysis struct {
	Items       []PhoneNumberAnalysis `json:"items"`
	TotalCount  int                   `json:"total_count"`
	CurrentPage int                   `json:"current_page"`
	PageSize    int                   `json:"page_size"`
	TotalPages  int                   `json:"total_pages"`
}
