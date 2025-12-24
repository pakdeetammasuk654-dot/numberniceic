package service

import (
	"fmt"
	"numberniceic/internal/core/domain"
	"regexp"
	"strconv"
	"strings"
	"unicode"
)

type ThaiChar struct {
	Original  string
	Consonant string
	Vowel     string
	ToneMark  string
	IsThai    bool
}

type NumerologyService struct {
	numerologyCache NumerologyValueProvider
	shadowCache     NumerologyValueProvider
	klakiniProvider KlakiniProvider
	numberPairCache NumberPairProvider
}

type NumerologyValueProvider interface {
	GetValue(char string) (int, bool)
}

type KlakiniProvider interface {
	IsKlakini(day string, r rune) bool
}

type NumberPairProvider interface {
	GetMeaning(pair string) (domain.NumberPairMeaning, bool)
}

func NewNumerologyService(numCache NumerologyValueProvider, shaCache NumerologyValueProvider, klaCache KlakiniProvider, pairCache NumberPairProvider) *NumerologyService {
	return &NumerologyService{
		numerologyCache: numCache,
		shadowCache:     shaCache,
		klakiniProvider: klaCache,
		numberPairCache: pairCache,
	}
}

func (s *NumerologyService) CalculateNameDetails(name string) *domain.SimilarNameResult {
	name = SanitizeInput(name)
	days := []string{"sunday", "monday", "tuesday", "wednesday1", "wednesday2", "thursday", "friday", "saturday"}
	result := &domain.SimilarNameResult{
		ThName: name,
	}

	// Calculate values
	decodedParts := DecodeName(name)
	var totalNumerologyValue, totalShadowValue int

	for _, thaiChar := range decodedParts {
		if thaiChar.IsThai {
			processComponent := func(charStr string) {
				if charStr == "" {
					return
				}
				numVal, _ := s.numerologyCache.GetValue(charStr)
				shaVal, _ := s.shadowCache.GetValue(charStr)
				totalNumerologyValue += numVal
				totalShadowValue += shaVal
			}
			processComponent(thaiChar.Consonant)
			processComponent(thaiChar.Vowel)
			processComponent(thaiChar.ToneMark)
		}
	}

	satPairs := formatTotalValue(totalNumerologyValue)
	shaPairs := formatTotalValue(totalShadowValue)
	result.SatNum = satPairs
	result.ShaNum = shaPairs

	// Calculate TSat and TSha (pair types)
	satMeanings, _, _ := s.getMeaningsAndScores(satPairs)
	shaMeanings, _, _ := s.getMeaningsAndScores(shaPairs)

	result.TSat = make([]domain.PairTypeInfo, len(satMeanings))
	for i, m := range satMeanings {
		result.TSat[i] = domain.PairTypeInfo{Type: m.Meaning.PairType, Color: m.Meaning.Color}
	}
	result.TSha = make([]domain.PairTypeInfo, len(shaMeanings))
	for i, m := range shaMeanings {
		result.TSha[i] = domain.PairTypeInfo{Type: m.Meaning.PairType, Color: m.Meaning.Color}
	}

	// Calculate Klakini for each day
	for _, day := range days {
		isKlakini := false
		for _, r := range name {
			if s.klakiniProvider.IsKlakini(day, r) {
				isKlakini = true
				break
			}
		}
		switch day {
		case "sunday":
			result.KSunday = isKlakini
		case "monday":
			result.KMonday = isKlakini
		case "tuesday":
			result.KTuesday = isKlakini
		case "wednesday1":
			result.KWednesday1 = isKlakini
		case "wednesday2":
			result.KWednesday2 = isKlakini
		case "thursday":
			result.KThursday = isKlakini
		case "friday":
			result.KFriday = isKlakini
		case "saturday":
			result.KSaturday = isKlakini
		}
	}

	return result
}

func (s *NumerologyService) getMeaningsAndScores(pairs []string) ([]domain.PairMeaningResult, int, int) {
	var meanings []domain.PairMeaningResult
	var posScore, negScore int
	for _, p := range pairs {
		if meaning, ok := s.numberPairCache.GetMeaning(p); ok {
			meanings = append(meanings, domain.PairMeaningResult{PairNumber: p, Meaning: meaning})
			if meaning.PairPoint > 0 {
				posScore += meaning.PairPoint
			} else {
				negScore += meaning.PairPoint
			}
		}
	}
	return meanings, posScore, negScore
}

func formatTotalValue(total int) []string {
	s := strconv.Itoa(total)
	if total < 0 {
		return []string{}
	}
	if len(s) < 2 {
		return []string{fmt.Sprintf("%02d", total)}
	}
	if len(s) == 2 {
		return []string{s}
	}

	var pairs []string
	if len(s)%2 != 0 {
		for i := 0; i < len(s)-1; i++ {
			pairs = append(pairs, s[i:i+2])
		}
	} else {
		for i := 0; i < len(s); i += 2 {
			pairs = append(pairs, s[i:i+2])
		}
	}
	return pairs
}

func SanitizeInput(input string) string {
	// First, remove invisible characters by checking unicode properties
	input = strings.Map(func(r rune) rune {
		if unicode.IsPrint(r) {
			return r
		}
		return -1
	}, input)

	reg := regexp.MustCompile(`[^a-zA-Z\p{Thai}\s]+`)
	cleaned := reg.ReplaceAllString(input, "")
	return strings.TrimSpace(cleaned)
}

func GetThaiDay(day string) string {
	normalizedDay := strings.ToLower(strings.TrimSpace(day))
	switch normalizedDay {
	case "sunday":
		return "วันอาทิตย์"
	case "monday":
		return "วันจันทร์"
	case "tuesday":
		return "วันอังคาร"
	case "wednesday1":
		return "วันพุธ (กลางวัน)"
	case "wednesday2":
		return "วันพุธ (กลางคืน)"
	case "thursday":
		return "วันพฤหัสบดี"
	case "friday":
		return "วันศุกร์"
	case "saturday":
		return "วันเสาร์"
	default:
		return strings.Title(normalizedDay)
	}
}

func GetPairTypeColor(pairType string) string {
	trimmedType := strings.TrimSpace(pairType)
	switch trimmedType {
	case "D10":
		return "#2E7D32"
	case "D8":
		return "#43A047"
	case "D5":
		return "#66BB6A"
	case "R10":
		return "#C62828"
	case "R7":
		return "#E53935"
	case "R5":
		return "#EF5350"
	default:
		return "#9E9E9E"
	}
}

// Helper functions for character classification
func isThaiConsonant(r rune) bool { return r >= 'ก' && r <= 'ฮ' }
func isLeadingVowel(r rune) bool {
	return r == 'เ' || r == 'แ' || r == 'โ' || r == 'ใ' || r == 'ไ'
}
func isUpperLowerVowel(r rune) bool {
	return r == '\u0E31' || (r >= '\u0E34' && r <= '\u0E37') || (r >= '\u0E38' && r <= '\u0E3A') || r == '\u0E47'
}
func isToneMark(r rune) bool      { return r >= '\u0E48' && r <= '\u0E4E' }
func isThaiCharacter(r rune) bool { return r >= 'ก' && r <= '๛' }

// DecodeName: Rewritten for accuracy
func DecodeName(name string) []ThaiChar {
	cleanedName := strings.TrimSpace(name)
	var result []ThaiChar
	runes := []rune(cleanedName)
	i := 0
	for i < len(runes) {
		r := runes[i]
		char := string(r)

		if r == ' ' {
			result = append(result, ThaiChar{Original: " ", IsThai: false})
			i++
			continue
		}

		// Handle leading vowels as their own character
		if isLeadingVowel(r) {
			result = append(result, ThaiChar{Original: char, Vowel: char, IsThai: true})
			i++
			continue
		}

		// Handle consonants and their attached marks
		if isThaiConsonant(r) {
			consonant := char
			original := char
			vowel := ""
			tone := ""
			i++ // Consume consonant

			// Look ahead for upper/lower vowels and tones
			for i < len(runes) {
				nextRune := runes[i]
				if isUpperLowerVowel(nextRune) {
					vowel += string(nextRune)
					original += string(nextRune)
					i++
				} else if isToneMark(nextRune) {
					tone += string(nextRune)
					original += string(nextRune)
					i++
				} else {
					break // Not an attached mark, stop
				}
			}
			result = append(result, ThaiChar{Original: original, Consonant: consonant, Vowel: vowel, ToneMark: tone, IsThai: true})
			continue
		}

		// Handle other Thai characters (like standalone า, ะ, or special chars)
		if isThaiCharacter(r) {
			result = append(result, ThaiChar{Original: char, Vowel: char, IsThai: true})
			i++
			continue
		}

		// Handle non-Thai characters
		result = append(result, ThaiChar{Original: char, IsThai: false})
		i++
	}
	return result
}
