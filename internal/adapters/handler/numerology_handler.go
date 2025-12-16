package handler

import (
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/core/service"
	"strings"
	"sync"

	"github.com/gofiber/fiber/v2"
)

type NumerologyHandler struct {
	numerologyCache *cache.NumerologyCache
	shadowCache     *cache.NumerologyCache
	klakiniCache    *cache.KlakiniCache
}

func NewNumerologyHandler(numCache, shaCache *cache.NumerologyCache, klaCache *cache.KlakiniCache) *NumerologyHandler {
	return &NumerologyHandler{
		numerologyCache: numCache,
		shadowCache:     shaCache,
		klakiniCache:    klaCache,
	}
}

type DecodedResult struct {
	Character       string `json:"character"`
	NumerologyValue int    `json:"numerology_value"`
	ShadowValue     int    `json:"shadow_value"`
	IsKlakini       bool   `json:"is_klakini"`
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	// --- Input Validation ---
	name := strings.TrimSpace(c.Query("name"))
	day := strings.ToUpper(strings.TrimSpace(c.Query("day")))

	if name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameter 'name' is required."})
	}
	if day == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameter 'day' (e.g., MONDAY) is required."})
	}

	// --- Concurrent Data Fetching ---
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

	wg.Wait() // Wait for both caches to be ready

	if numErr != nil {
		log.Printf("Error getting numerology data from cache: %v", numErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not retrieve numerology data."})
	}
	if shaErr != nil {
		log.Printf("Error getting shadow numerology data from cache: %v", shaErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not retrieve shadow numerology data."})
	}

	// --- Processing ---
	decodedChars := service.DecodeName(name)
	var results []DecodedResult
	var totalNumerologyValue, totalShadowValue int
	var klakiniChars []string

	for _, thaiChar := range decodedChars {
		if !thaiChar.IsThai {
			continue
		}

		processChar := func(charStr string) {
			numVal, _ := numerologyData[charStr]
			shaVal, _ := shadowData[charStr]
			
			// Klakini check is fast, no need for goroutine here
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

	// --- Response ---
	return c.JSON(fiber.Map{
		"input_name":             c.Query("name"),
		"input_day":              c.Query("day"),
		"total_numerology_value": totalNumerologyValue,
		"total_shadow_value":     totalShadowValue,
		"klakini_characters":     klakiniChars,
		"decoded_parts":          results,
	})
}
