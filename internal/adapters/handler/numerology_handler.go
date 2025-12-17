package handler

import (
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"numberniceic/internal/core/service"
	"strconv"
	"strings"
	"sync"

	"github.com/gofiber/fiber/v2"
)

// Struct definitions
type DecodedResult struct {
	Character       string `json:"character"`
	NumerologyValue int    `json:"numerology_value"`
	ShadowValue     int    `json:"shadow_value"`
	IsKlakini       bool   `json:"is_klakini"`
}

type PairMeaningResult struct {
	PairNumber string                   `json:"pair_number"`
	Meaning    domain.NumberPairMeaning `json:"meaning"`
}

type DisplayChar struct {
	Char  string
	IsBad bool
}

type SampleName struct {
	Name      string
	AvatarURL string
}

type NumerologyHandler struct {
	numerologyCache  *cache.NumerologyCache
	shadowCache      *cache.NumerologyCache
	klakiniCache     *cache.KlakiniCache
	numberPairCache  *cache.NumberPairCache
	namesMiracleRepo ports.NamesMiracleRepository
}

func NewNumerologyHandler(
	numCache, shaCache *cache.NumerologyCache,
	klaCache *cache.KlakiniCache,
	pairCache *cache.NumberPairCache,
	namesRepo ports.NamesMiracleRepository,
) *NumerologyHandler {
	return &NumerologyHandler{
		numerologyCache:  numCache,
		shadowCache:      shaCache,
		klakiniCache:     klaCache,
		numberPairCache:  pairCache,
		namesMiracleRepo: namesRepo,
	}
}

func isHtmxRequest(c *fiber.Ctx) bool {
	return c.Get("HX-Request") == "true"
}

func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if name == "" || day == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameters 'name' and 'day' are required."})
	}
	limit := 12
	similarNames, err := h.namesMiracleRepo.GetSimilarNames(name, day, limit)
	if err != nil {
		log.Printf("Error getting similar names: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to retrieve similar names."})
	}

	if isHtmxRequest(c) {
		return c.Render("similar_names", similarNames)
	}
	return c.JSON(similarNames)
}

func (h *NumerologyHandler) GetAuspiciousNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if name == "" || day == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameters 'name' and 'day' are required."})
	}
	limit := 12
	auspiciousNames, err := h.namesMiracleRepo.GetAuspiciousNames(name, day, limit)
	if err != nil {
		log.Printf("Error getting auspicious names: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to retrieve auspicious names."})
	}

	if isHtmxRequest(c) {
		return c.Render("similar_names", auspiciousNames)
	}
	return c.JSON(auspiciousNames)
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))

	// FIX: If name is empty, return empty success instead of error
	// This allows HTMX to clear the result area without breaking
	if name == "" {
		if isHtmxRequest(c) {
			return c.SendString("") // Return empty string to clear the target div
		}
		return c.JSON(fiber.Map{}) // Return empty JSON
	}

	if day == "" {
		// Default to Sunday if day is missing (safety fallback)
		day = "sunday"
	}

	var numerologyData, shadowData map[string]int
	var numErr, shaErr error
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		numerologyData, numErr = h.numerologyCache.GetAll()
	}()
	go func() {
		defer wg.Done()
		shadowData, shaErr = h.shadowCache.GetAll()
	}()
	wg.Wait()

	if numErr != nil || shaErr != nil {
		log.Printf("Cache error: numErr=%v, shaErr=%v", numErr, shaErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not retrieve base numerology data."})
	}

	decodedChars := service.DecodeName(name)
	var results []DecodedResult
	var totalNumerologyValue, totalShadowValue int
	var klakiniChars []string
	var displayChars []DisplayChar

	for _, thaiChar := range decodedChars {
		// Calculation Logic
		if thaiChar.IsThai {
			processComponent := func(charStr string) {
				if charStr == "" {
					return
				}
				numVal := numerologyData[charStr]
				shaVal := shadowData[charStr]
				isKla := h.klakiniCache.IsKlakini(day, []rune(charStr)[0])
				results = append(results, DecodedResult{charStr, numVal, shaVal, isKla})
				totalNumerologyValue += numVal
				totalShadowValue += shaVal
			}
			processComponent(thaiChar.Consonant)
			processComponent(thaiChar.Vowel)
			processComponent(thaiChar.ToneMark)
		}

		// Display Logic
		for _, r := range thaiChar.Original {
			isBad := h.klakiniCache.IsKlakini(day, r)
			displayChars = append(displayChars, DisplayChar{string(r), isBad})
			if isBad {
				found := false
				for _, existing := range klakiniChars {
					if existing == string(r) {
						found = true
						break
					}
				}
				if !found {
					klakiniChars = append(klakiniChars, string(r))
				}
			}
		}
	}

	numerologyPairs := formatTotalValue(totalNumerologyValue)
	shadowPairs := formatTotalValue(totalShadowValue)

	numMeanings, numPos, numNeg := getMeaningsAndScores(numerologyPairs, h.numberPairCache)
	shaMeanings, shaPos, shaNeg := getMeaningsAndScores(shadowPairs, h.numberPairCache)

	grandTotalScore := numPos + numNeg + shaPos + shaNeg
	isSunDead := grandTotalScore < 0

	responseData := fiber.Map{
		"input_name":             c.Query("name"),
		"cleaned_name":           name,
		"display_chars":          displayChars,
		"input_day":              service.GetThaiDay(day),
		"total_numerology_value": totalNumerologyValue,
		"total_shadow_value":     totalShadowValue,
		"numerology_pairs":       numMeanings,
		"shadow_pairs":           shaMeanings,
		"klakini_characters":     klakiniChars,
		"decoded_parts":          results,
		"num_positive_score":     numPos,
		"num_negative_score":     numNeg,
		"sha_positive_score":     shaPos,
		"sha_negative_score":     shaNeg,
		"grand_total_score":      grandTotalScore,
		"is_sun_dead":            isSunDead,
	}

	if isHtmxRequest(c) {
		return c.Render("decode", responseData)
	}
	return c.JSON(responseData)
}

func getMeaningsAndScores(pairs []string, pairCache *cache.NumberPairCache) ([]PairMeaningResult, int, int) {
	var meanings []PairMeaningResult
	var posScore, negScore int
	for _, p := range pairs {
		if meaning, ok := pairCache.GetMeaning(p); ok {
			meanings = append(meanings, PairMeaningResult{PairNumber: p, Meaning: meaning})
			if meaning.PairPoint > 0 {
				posScore += meaning.PairPoint
			} else {
				negScore += meaning.PairPoint
			}
		}
	}
	return meanings, posScore, negScore
}

// formatTotalValue corrected to handle all multi-digit numbers by splitting into pairs.
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
	// If length is odd (e.g., 3, 5), use overlapping pairs.
	if len(s)%2 != 0 {
		for i := 0; i < len(s)-1; i++ {
			pairs = append(pairs, s[i:i+2])
		}
	} else { // If length is even (e.g., 4, 6), use non-overlapping pairs.
		for i := 0; i < len(s); i += 2 {
			pairs = append(pairs, s[i:i+2])
		}
	}
	return pairs
}
