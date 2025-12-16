package domain

// Numerology represents the mapping between a character and its numerological value.
// This is used for both "Sat Num" (Numerology) and "Sha Num" (Shadow Numerology).
type Numerology struct {
	Character string
	Value     int
}
