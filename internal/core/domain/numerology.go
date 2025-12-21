package domain

// Numerology represents the mapping between a character and its numerological value.
// This is used for both "Sat Num" (Numerology) and "Sha Num" (Shadow Numerology).
type Numerology struct {
	Character string
	Value     int
}

type DecodedResult struct {
	Character       string `json:"character"`
	NumerologyValue int    `json:"numerology_value"`
	ShadowValue     int    `json:"shadow_value"`
	IsKlakini       bool   `json:"is_klakini"`
}

type PairMeaningResult struct {
	PairNumber string            `json:"pair_number"`
	Meaning    NumberPairMeaning `json:"meaning"`
}
