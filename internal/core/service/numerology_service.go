package service

import (
	"strings"
)

// ThaiChar represents a decomposed Thai character (consonant, vowel, tone mark).
type ThaiChar struct {
	Original  string
	Consonant string
	Vowel     string
	ToneMark  string
	IsThai    bool
}

// DecodeName takes a Thai name string and breaks it down into its constituent characters.
// It handles consonants, vowels (including complex ones), and tone marks.
func DecodeName(name string) []ThaiChar {
	// Normalize and clean the input string
	cleanedName := strings.ReplaceAll(name, " ", "") // Allow spaces between names but remove them for processing
	cleanedName = strings.TrimSpace(cleanedName)

	var result []ThaiChar
	var tempVowel string

	runes := []rune(cleanedName)
	for i := 0; i < len(runes); i++ {
		r := runes[i]
		char := string(r)

		// Check if it's a Thai character
		if !isThaiCharacter(r) {
			result = append(result, ThaiChar{Original: char, IsThai: false})
			continue
		}

		// Thai character processing
		if isThaiConsonant(r) {
			// If there was a pending vowel, it means the previous character was a standalone vowel.
			if tempVowel != "" {
				result = append(result, ThaiChar{Original: tempVowel, Vowel: tempVowel, IsThai: true})
				tempVowel = ""
			}

			// Look ahead for vowels and tone marks associated with this consonant
			consonant := char
			var vowel, tone string

			// Lookahead for following vowels/tones
			for j := i + 1; j < len(runes); j++ {
				nextRune := runes[j]
				if isThaiVowel(nextRune) || isThaiToneMark(nextRune) {
					if isThaiVowel(nextRune) {
						vowel += string(nextRune)
					} else if isThaiToneMark(nextRune) {
						tone += string(nextRune)
					}
					i++ // Consume this character
				} else {
					break // Not a following vowel/tone, stop lookahead
				}
			}
			result = append(result, ThaiChar{
				Original:  consonant + vowel + tone,
				Consonant: consonant,
				Vowel:     vowel,
				ToneMark:  tone,
				IsThai:    true,
			})
		} else if isThaiVowel(r) {
			// Could be a leading vowel like เ, แ, โ, ใ, ไ
			tempVowel += char
		} else {
			// Other characters (like ฯ, ๏) - treat as standalone
			if tempVowel != "" {
				result = append(result, ThaiChar{Original: tempVowel, Vowel: tempVowel, IsThai: true})
				tempVowel = ""
			}
			result = append(result, ThaiChar{Original: char, IsThai: true})
		}
	}

	// If there's a trailing standalone vowel
	if tempVowel != "" {
		result = append(result, ThaiChar{Original: tempVowel, Vowel: tempVowel, IsThai: true})
	}

	return result
}

func isThaiCharacter(r rune) bool {
	return r >= 'ก' && r <= '๛'
}

func isThaiConsonant(r rune) bool {
	return r >= 'ก' && r <= 'ฮ'
}

func isThaiVowel(r rune) bool {
	// Includes vowels and some symbols that act like vowels
	return (r >= '\u0E30' && r <= '\u0E3A') || (r >= '\u0E47' && r <= '\u0E4E')
}

func isThaiToneMark(r rune) bool {
	return r >= '\u0E48' && r <= '\u0E4B'
}
