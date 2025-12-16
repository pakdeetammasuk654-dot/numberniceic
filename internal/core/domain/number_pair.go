package domain

type NumberPairMeaning struct {
	PairNumber    string `json:"pair_number"`
	PairType      string `json:"pair_type"`
	MiracleDetail string `json:"miracle_detail"`
	MiracleDesc   string `json:"miracle_desc"`
	PairPoint     int    `json:"pair_point"`
	Color         string `json:"color"` // New field for color
}
