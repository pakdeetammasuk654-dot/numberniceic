package service

import (
	"regexp"
	"strings"
)

type ThaiChar struct {
	Original  string
	Consonant string
	Vowel     string
	ToneMark  string
	IsThai    bool
}

func SanitizeInput(input string) string {
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
