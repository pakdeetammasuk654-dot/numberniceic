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

func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	// Sanitize input name
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

	return c.JSON(similarNames)
}

func (h *NumerologyHandler) GetAuspiciousNames(c *fiber.Ctx) error {
	// Sanitize input name
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

	return c.JSON(auspiciousNames)
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	// Sanitize input name
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToUpper(strings.TrimSpace(c.Query("day")))

	if name == "" || day == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameters 'name' and 'day' are required."})
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

	for _, thaiChar := range decodedChars {
		if !thaiChar.IsThai {
			continue
		}
		processChar := func(charStr string) {
			numVal := numerologyData[charStr]
			shaVal := shadowData[charStr]
			isKla := h.klakiniCache.IsKlakini(day, []rune(charStr)[0])
			results = append(results, DecodedResult{
				Character:       charStr,
				NumerologyValue: numVal,
				ShadowValue:     shaVal,
				IsKlakini:       isKla,
			})
			totalNumerologyValue += numVal
			totalShadowValue += shaVal
			if isKla {
				klakiniChars = append(klakiniChars, charStr)
			}
		}
		if thaiChar.Consonant != "" {
			processChar(thaiChar.Consonant)
		}
		for _, vowelRune := range thaiChar.Vowel {
			processChar(string(vowelRune))
		}
	}

	numerologyPairs := formatTotalValue(totalNumerologyValue)
	shadowPairs := formatTotalValue(totalShadowValue)

	getMeanings := func(pairs []string) []PairMeaningResult {
		var meanings []PairMeaningResult
		for _, p := range pairs {
			if meaning, ok := h.numberPairCache.GetMeaning(p); ok {
				meanings = append(meanings, PairMeaningResult{PairNumber: p, Meaning: meaning})
			}
		}
		return meanings
	}

	return c.JSON(fiber.Map{
		"input_name":             c.Query("name"),
		"cleaned_name":           name, // Return the sanitized name
		"total_numerology_value": totalNumerologyValue,
		"total_shadow_value":     totalShadowValue,
		"numerology_pairs":       getMeanings(numerologyPairs),
		"shadow_pairs":           getMeanings(shadowPairs),
		"klakini_characters":     klakiniChars,
		"decoded_parts":          results,
	})
}

func formatTotalValue(total int) []string {
	s := strconv.Itoa(total)
	if total < 0 {
		return []string{}
	}
	if total < 10 {
		return []string{fmt.Sprintf("%02d", total)}
	}
	if total < 100 {
		return []string{s}
	}
	var pairs []string
	for i := 0; i < len(s)-1; i++ {
		pairs = append(pairs, s[i:i+2])
	}
	return pairs
}
