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

const PageSize = 12
const MaxSearchIterations = 10 // To prevent infinite loops, max 10 * 12 = 120 names to check

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

// calculateScoresForSimilarNames calculates the total score and populates TSat/TSha for a list of similar names.
func (h *NumerologyHandler) calculateScoresForSimilarNames(names []domain.SimilarNameResult) {
	for i := range names {
		satMeanings, satPos, satNeg := getMeaningsAndScores(names[i].SatNum, h.numberPairCache)
		shaMeanings, shaPos, shaNeg := getMeaningsAndScores(names[i].ShaNum, h.numberPairCache)

		names[i].TotalScore = satPos + satNeg + shaPos + shaNeg

		// Convert and assign TSat
		names[i].TSat = make([]domain.PairTypeInfo, len(satMeanings))
		for j, meaning := range satMeanings {
			names[i].TSat[j] = domain.PairTypeInfo{
				Type:  meaning.Meaning.PairType,
				Color: meaning.Meaning.Color,
			}
		}

		// Convert and assign TSha
		names[i].TSha = make([]domain.PairTypeInfo, len(shaMeanings))
		for j, meaning := range shaMeanings {
			names[i].TSha[j] = domain.PairTypeInfo{
				Type:  meaning.Meaning.PairType,
				Color: meaning.Meaning.Color,
			}
		}
	}
}

// findAuspiciousNames iteratively fetches and filters names until it finds enough auspicious ones.
func (h *NumerologyHandler) findAuspiciousNames(name, day string) ([]domain.SimilarNameResult, error) {
	var auspiciousNames []domain.SimilarNameResult
	offset := 0

	for i := 0; i < MaxSearchIterations && len(auspiciousNames) < PageSize; i++ {
		// Fetch a batch of names
		candidates, err := h.namesMiracleRepo.GetAuspiciousNames(name, day, PageSize, offset)
		if err != nil {
			return nil, fmt.Errorf("error fetching candidates on iteration %d: %w", i, err)
		}
		// If no more candidates are found, break the loop
		if len(candidates) == 0 {
			break
		}

		// Calculate scores for the new candidates
		h.calculateScoresForSimilarNames(candidates)

		// Filter for names where ALL pairs are good (no negative scores in Sat or Sha)
		for _, candidate := range candidates {
			// Check Numerology (Sat) for any negative score
			_, _, satNeg := getMeaningsAndScores(candidate.SatNum, h.numberPairCache)
			// Check Shadow (Sha) for any negative score
			_, _, shaNeg := getMeaningsAndScores(candidate.ShaNum, h.numberPairCache)

			// Both must have 0 negative score to be considered "All Good" (Green)
			if satNeg == 0 && shaNeg == 0 {
				auspiciousNames = append(auspiciousNames, candidate)
				// If we have enough, we can stop early
				if len(auspiciousNames) == PageSize {
					break
				}
			}
		}

		// Prepare for the next iteration
		offset += PageSize
	}

	// Note: We do NOT sort by score here.
	// The names are appended in the order they were fetched from the DB (Similarity DESC).

	return auspiciousNames, nil
}

// GetSimilarNames now handles both similar and auspicious names for the partial view
func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))

	// Robust boolean parsing
	auspiciousParam := c.Query("auspicious")
	isAuspicious := auspiciousParam == "true" || auspiciousParam == "on" || auspiciousParam == "1"

	if name == "" || day == "" {
		return c.SendString("<!-- Missing parameters -->")
	}

	var similarNames []domain.SimilarNameResult
	var err error

	if isAuspicious {
		similarNames, err = h.findAuspiciousNames(name, day)
	} else {
		similarNames, err = h.namesMiracleRepo.GetSimilarNames(name, day, PageSize, 0)
		if err == nil {
			h.calculateScoresForSimilarNames(similarNames)
		}
	}

	if err != nil {
		log.Printf("Error getting names: %v", err)
		return c.SendString("<div>Error loading names.</div>")
	}

	// We need display_chars for the header
	decodedChars := service.DecodeName(name)
	var displayChars []DisplayChar
	for _, thaiChar := range decodedChars {
		for _, r := range thaiChar.Original {
			isBad := h.klakiniCache.IsKlakini(day, r)
			displayChars = append(displayChars, DisplayChar{string(r), isBad})
		}
	}

	// This now renders ONLY the partial, and HTMX will swap it into the right place.
	return c.Render("partials/similar_names_section", fiber.Map{
		"similar_names": similarNames,
		"is_auspicious": isAuspicious,
		"display_chars": displayChars,
		"cleaned_name":  name,
		"AnimateHeader": false, // We don't want to re-animate this partial
	})
}

func (h *NumerologyHandler) GetAuspiciousNames(c *fiber.Ctx) error {
	return h.GetSimilarNames(c)
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))

	// Robust boolean parsing
	auspiciousParam := c.Query("auspicious")
	isAuspicious := auspiciousParam == "true" || auspiciousParam == "on" || auspiciousParam == "1"

	if name == "" {
		if isHtmxRequest(c) {
			return c.SendString("")
		}
		return c.JSON(fiber.Map{})
	}

	if day == "" {
		day = "sunday"
	}

	// --- Fetch and Process Names (Synchronously) ---
	var similarNames []domain.SimilarNameResult
	var err error

	if isAuspicious {
		similarNames, err = h.findAuspiciousNames(name, day)
	} else {
		similarNames, err = h.namesMiracleRepo.GetSimilarNames(name, day, PageSize, 0)
		if err == nil {
			h.calculateScoresForSimilarNames(similarNames)
		}
	}

	if err != nil {
		log.Printf("Error in Decode (processNames): %v", err)
		similarNames = []domain.SimilarNameResult{}
	}

	// --- Analyze Name (Numerology) ---
	var analysisData fiber.Map
	var analysisErr error
	var allUniquePairs []PairMeaningResult
	var displayChars []DisplayChar

	var wg sync.WaitGroup
	wg.Add(1)
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
		sort.Slice(allUniquePairs, func(i, j int) bool {
			return allUniquePairs[i].Meaning.PairPoint > allUniquePairs[j].Meaning.PairPoint
		})

		analysisData = fiber.Map{
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

	wg.Wait()

	if analysisErr != nil {
		log.Printf("Error in Decode (Analysis): %v", analysisErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not process request."})
	}

	responseData := fiber.Map{
		"input_name":       c.Query("name"),
		"cleaned_name":     name,
		"input_day":        service.GetThaiDay(day),
		"input_day_raw":    day,
		"similar_names":    similarNames,
		"is_auspicious":    isAuspicious,
		"all_unique_pairs": allUniquePairs,
		"display_chars":    displayChars,
		"AnimateHeader":    true,
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
