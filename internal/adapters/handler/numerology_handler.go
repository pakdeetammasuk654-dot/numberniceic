package handler

import (
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"numberniceic/internal/core/service"
	"sort"
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

type NumerologyHandler struct {
	numerologyCache   *cache.NumerologyCache
	shadowCache       *cache.NumerologyCache
	klakiniCache      *cache.KlakiniCache
	numberPairCache   *cache.NumberPairCache
	namesMiracleRepo  ports.NamesMiracleRepository
	linguisticService *service.LinguisticService
}

func NewNumerologyHandler(
	numCache, shaCache *cache.NumerologyCache,
	klaCache *cache.KlakiniCache,
	pairCache *cache.NumberPairCache,
	namesRepo ports.NamesMiracleRepository,
	lingoService *service.LinguisticService,
) *NumerologyHandler {
	return &NumerologyHandler{
		numerologyCache:   numCache,
		shadowCache:       shaCache,
		klakiniCache:      klaCache,
		numberPairCache:   pairCache,
		namesMiracleRepo:  namesRepo,
		linguisticService: lingoService,
	}
}

func isHtmxRequest(c *fiber.Ctx) bool {
	return c.Get("HX-Request") == "true"
}

func (h *NumerologyHandler) AnalyzeLinguistically(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	if name == "" {
		return c.Status(fiber.StatusBadRequest).SendString("Name parameter is required.")
	}

	analysis, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		log.Printf("Error from linguistic service: %v", err)
		return c.Status(fiber.StatusInternalServerError).SendString("Failed to analyze name linguistically.")
	}

	return c.Render("partials/linguistic_modal", fiber.Map{
		"Name":     name,
		"Analysis": analysis,
	})
}

func (h *NumerologyHandler) GetNumberMeanings(c *fiber.Ctx) error {
	meaningsMap, err := h.numberPairCache.GetAllMeanings()
	if err != nil {
		log.Printf("Error getting number meanings from cache: %v", err)
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading meanings.")
	}

	// Convert map to slice for sorting
	var meanings []domain.NumberPairMeaning
	for _, meaning := range meaningsMap {
		meanings = append(meanings, meaning)
	}

	// Sort by PairNumber
	sort.Slice(meanings, func(i, j int) bool {
		return meanings[i].PairNumber < meanings[j].PairNumber
	})

	return c.Render("partials/number_meanings_modal", meanings)
}

func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if name == "" || day == "" {
		// Return empty content if params are missing for an HTMX request
		if isHtmxRequest(c) {
			return c.SendString("")
		}
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Query parameters 'name' and 'day' are required."})
	}
	limit := 12
	similarNames, err := h.namesMiracleRepo.GetSimilarNames(name, day, limit)
	if err != nil {
		log.Printf("Error getting similar names: %v", err)
		// Return empty content on error for an HTMX request
		if isHtmxRequest(c) {
			return c.SendString("<div>เกิดข้อผิดพลาดในการค้นหาชื่อใกล้เคียง</div>")
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to retrieve similar names."})
	}

	if isHtmxRequest(c) {
		// Pass the slice directly as the data context for the template
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
	isAuspicious := c.Query("auspicious") == "true"

	if name == "" {
		if isHtmxRequest(c) {
			return c.SendString("")
		}
		return c.JSON(fiber.Map{})
	}

	if day == "" {
		day = "sunday"
	}

	var wg sync.WaitGroup
	wg.Add(2) // Two concurrent tasks: analysis and similar names fetching

	// --- Task 1: Fetch Similar/Auspicious Names ---
	var similarNames []domain.SimilarNameResult
	var similarNamesErr error
	go func() {
		defer wg.Done()
		if isAuspicious {
			similarNames, similarNamesErr = h.namesMiracleRepo.GetAuspiciousNames(name, day, 12)
		} else {
			similarNames, similarNamesErr = h.namesMiracleRepo.GetSimilarNames(name, day, 12)
		}
		if similarNamesErr != nil {
			log.Printf("Error getting names in Decode: %v", similarNamesErr)
			similarNames = []domain.SimilarNameResult{} // Ensure it's not nil
		}
	}()

	// --- Task 2: Perform Name Analysis ---
	var analysisData fiber.Map
	var analysisErr error
	var allUniquePairs []PairMeaningResult
	go func() {
		defer wg.Done()
		numerologyData, numErr := h.numerologyCache.GetAll()
		shadowData, shaErr := h.shadowCache.GetAll()
		if numErr != nil || shaErr != nil {
			analysisErr = fmt.Errorf("cache error: numErr=%v, shaErr=%v", numErr, shaErr)
			return
		}

		decodedChars := service.DecodeName(name)
		var results []DecodedResult
		var totalNumerologyValue, totalShadowValue int
		var klakiniChars []string
		var displayChars []DisplayChar

		for _, thaiChar := range decodedChars {
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
			for _, r := range thaiChar.Original {
				isBad := h.klakiniCache.IsKlakini(day, r)
				displayChars = append(displayChars, DisplayChar{string(r), isBad})
				if isBad && !contains(klakiniChars, string(r)) {
					klakiniChars = append(klakiniChars, string(r))
				}
			}
		}

		numerologyPairs := formatTotalValue(totalNumerologyValue)
		shadowPairs := formatTotalValue(totalShadowValue)
		numMeanings, numPos, numNeg := getMeaningsAndScores(numerologyPairs, h.numberPairCache)
		shaMeanings, shaPos, shaNeg := getMeaningsAndScores(shadowPairs, h.numberPairCache)
		grandTotalScore := numPos + numNeg + shaPos + shaNeg

		// Combine and find unique pairs for the modal
		seenPairs := make(map[string]bool)
		for _, pair := range numMeanings {
			if !seenPairs[pair.PairNumber] {
				allUniquePairs = append(allUniquePairs, pair)
				seenPairs[pair.PairNumber] = true
			}
		}
		for _, pair := range shaMeanings {
			if !seenPairs[pair.PairNumber] {
				allUniquePairs = append(allUniquePairs, pair)
				seenPairs[pair.PairNumber] = true
			}
		}
		// Sort by score (PairPoint) descending
		sort.Slice(allUniquePairs, func(i, j int) bool {
			return allUniquePairs[i].Meaning.PairPoint > allUniquePairs[j].Meaning.PairPoint
		})

		analysisData = fiber.Map{
			"display_chars":          displayChars,
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
			"is_sun_dead":            grandTotalScore < 0,
		}
	}()

	wg.Wait() // Wait for both tasks to complete

	if analysisErr != nil {
		log.Printf("Analysis error: %v", analysisErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not perform name analysis."})
	}

	// Combine results
	responseData := fiber.Map{
		"input_name":       c.Query("name"),
		"cleaned_name":     name,
		"input_day":        service.GetThaiDay(day),
		"input_day_raw":    day,
		"similar_names":    similarNames,
		"is_auspicious":    isAuspicious,
		"all_unique_pairs": allUniquePairs,
	}
	for k, v := range analysisData {
		responseData[k] = v
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

func contains(slice []string, item string) bool {
	for _, a := range slice {
		if a == item {
			return true
		}
	}
	return false
}
