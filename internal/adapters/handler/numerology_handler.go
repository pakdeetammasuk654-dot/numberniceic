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

	"github.com/gofiber/fiber/v2"
)

const PageSize = 100
const SearchBatchSize = 200

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

	var meanings []domain.NumberPairMeaning
	for _, meaning := range meaningsMap {
		meanings = append(meanings, meaning)
	}

	sort.Slice(meanings, func(i, j int) bool {
		return meanings[i].PairNumber < meanings[j].PairNumber
	})

	return c.Render("partials/number_meanings_modal", meanings)
}

// calculateScoresAndHighlights calculates scores and also generates the DisplayNameHTML for each name.
func (h *NumerologyHandler) calculateScoresAndHighlights(names []domain.SimilarNameResult, day string) {
	for i := range names {
		satMeanings, satPos, satNeg := getMeaningsAndScores(names[i].SatNum, h.numberPairCache)
		shaMeanings, shaPos, shaNeg := getMeaningsAndScores(names[i].ShaNum, h.numberPairCache)
		names[i].TotalScore = satPos + satNeg + shaPos + shaNeg
		names[i].IsTopTier = h.isAllPairsTopTier(names[i].ThName, names[i].SatNum, h.numberPairCache) &&
			h.isAllPairsTopTier(names[i].ThName, names[i].ShaNum, h.numberPairCache)

		// Generate display characters for the name, always as non-Klakini (black text).
		var displayChars []domain.DisplayChar
		for _, r := range names[i].ThName {
			displayChars = append(displayChars, domain.DisplayChar{Char: string(r), IsBad: false})
		}
		names[i].DisplayNameHTML = displayChars

		// Populate the KlakiniChars field with actual Klakini characters.
		var klakiniChars []string
		for _, r := range names[i].ThName {
			if h.klakiniCache.IsKlakini(day, r) {
				klakiniChars = append(klakiniChars, string(r))
			}
		}
		names[i].KlakiniChars = klakiniChars

		names[i].TSat = make([]domain.PairTypeInfo, len(satMeanings))
		for j, meaning := range satMeanings {
			names[i].TSat[j] = domain.PairTypeInfo{Type: meaning.Meaning.PairType, Color: meaning.Meaning.Color}
		}
		names[i].TSha = make([]domain.PairTypeInfo, len(shaMeanings))
		for j, meaning := range shaMeanings {
			names[i].TSha[j] = domain.PairTypeInfo{Type: meaning.Meaning.PairType, Color: meaning.Meaning.Color}
		}
	}
}

func (h *NumerologyHandler) isAllPairsTopTier(name string, pairs []string, pairCache *cache.NumberPairCache) bool {
	for _, p := range pairs {
		if p == "" {
			continue
		}
		if meaning, ok := pairCache.GetMeaning(p); ok {
			switch meaning.PairType {
			case "D10", "D8", "D5":
			default:
				return false
			}
		} else {
			return false
		}
	}
	return true
}

// findBestConsonant finds the first consonant in a name that is not a klakini for the given day.
func (h *NumerologyHandler) findBestConsonant(name, day string) string {
	firstConsonant := ""
	for _, r := range name {
		// Skip leading vowels
		switch r {
		case 'เ', 'แ', 'โ', 'ใ', 'ไ':
			continue
		}
		// Check if the character is a klakini
		if !h.klakiniCache.IsKlakini(day, r) {
			return string(r) // Found a non-klakini consonant
		}
		// If it's a klakini but it's the first consonant we've seen, store it as a fallback
		if firstConsonant == "" {
			firstConsonant = string(r)
		}
	}
	// If all consonants are klakini, return the first one found. If no consonants, return empty.
	return firstConsonant
}

func (h *NumerologyHandler) findAuspiciousNames(name, day string, allowKlakini bool) ([]domain.SimilarNameResult, error) {
	var auspiciousNames []domain.SimilarNameResult
	offset := 0

	// Determine the best consonant to use for sorting/prioritizing
	preferredConsonant := h.findBestConsonant(name, day)
	if allowKlakini {
		// If klakini is allowed, just use the first consonant regardless
		for _, r := range name {
			if r != 'เ' && r != 'แ' && r != 'โ' && r != 'ใ' && r != 'ไ' {
				preferredConsonant = string(r)
				break
			}
		}
	}

	for {
		// Use GetAuspiciousNames which has the correct query logic (no similarity threshold)
		candidates, err := h.namesMiracleRepo.GetAuspiciousNames(name, preferredConsonant, day, SearchBatchSize, offset, allowKlakini)
		if err != nil {
			return nil, fmt.Errorf("error fetching candidates at offset %d: %w", offset, err)
		}
		if len(candidates) == 0 {
			break
		}
		for _, candidate := range candidates {
			if h.isAllPairsTopTier(candidate.ThName, candidate.SatNum, h.numberPairCache) && h.isAllPairsTopTier(candidate.ThName, candidate.ShaNum, h.numberPairCache) {
				auspiciousNames = append(auspiciousNames, candidate)
				if len(auspiciousNames) >= PageSize {
					break
				}
			}
		}
		if len(auspiciousNames) >= PageSize {
			break
		}
		offset += len(candidates)
	}
	return auspiciousNames, nil
}

// createDisplayChars generates display characters with true Klakini status.
// It ALWAYS checks for Klakini characters based on the day, regardless of any search settings.
// This ensures consistent display (red color) across the application.
func (h *NumerologyHandler) createDisplayChars(name, day string) []domain.DisplayChar {
	var displayChars []domain.DisplayChar
	// Iterate over each rune (character) in the name
	for _, r := range name {
		isBad := h.klakiniCache.IsKlakini(day, r)
		displayChars = append(displayChars, domain.DisplayChar{Char: string(r), IsBad: isBad})
	}
	return displayChars
}

func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1"
	allowKlakini := c.Query("allow_klakini") == "true" || c.Query("allow_klakini") == "on" || c.Query("allow_klakini") == "1"

	if name == "" || day == "" {
		return c.SendString("<!-- Missing parameters -->")
	}

	var similarNames []domain.SimilarNameResult
	var err error
	if isAuspicious {
		similarNames, err = h.findAuspiciousNames(name, day, allowKlakini)
	} else {
		similarNames, err = h.namesMiracleRepo.GetSimilarNames(name, day, PageSize, 0, allowKlakini)
		if err == nil && len(similarNames) < PageSize {
			needed := PageSize - len(similarNames)
			excludedIDs := make([]int, len(similarNames))
			for i, n := range similarNames {
				excludedIDs[i] = n.NameID
			}

			preferredConsonant := h.findBestConsonant(name, day)
			if allowKlakini {
				for _, r := range name {
					if r != 'เ' && r != 'แ' && r != 'โ' && r != 'ใ' && r != 'ไ' {
						preferredConsonant = string(r)
						break
					}
				}
			}

			fallbackNames, fallbackErr := h.namesMiracleRepo.GetFallbackNames(name, preferredConsonant, day, needed, allowKlakini, excludedIDs)
			if fallbackErr == nil {
				similarNames = append(similarNames, fallbackNames...)
			} else {
				log.Printf("Error getting fallback names: %v", fallbackErr)
			}
		}
	}

	if err != nil {
		log.Printf("Error getting names: %v", err)
		return c.SendString("<div>Error loading names.</div>")
	}

	h.calculateScoresAndHighlights(similarNames, day)

	// Create display chars for the header (always true Klakini status)
	displayNameHTML := h.createDisplayChars(name, day)
	var klakiniChars []string
	for _, dc := range displayNameHTML {
		if dc.IsBad {
			klakiniChars = append(klakiniChars, dc.Char)
		}
	}

	return c.Render("partials/similar_names_section", fiber.Map{
		"similar_names":      similarNames,
		"is_auspicious":      isAuspicious,
		"allow_klakini":      allowKlakini,
		"DisplayNameHTML":    displayNameHTML,
		"klakini_characters": klakiniChars,
		"cleaned_name":       name,
		"input_day":          service.GetThaiDay(day),
		"AnimateHeader":      false,
	})
}

func (h *NumerologyHandler) GetAuspiciousNames(c *fiber.Ctx) error {
	return h.GetSimilarNames(c)
}

func (h *NumerologyHandler) GetSolarSystem(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	allowKlakini := c.Query("allow_klakini") == "true" || c.Query("allow_klakini") == "on" || c.Query("allow_klakini") == "1"

	if name == "" || day == "" {
		return c.SendString("<!-- Missing parameters -->")
	}

	var analysisData fiber.Map
	var analysisErr error

	var allUniquePairs []PairMeaningResult
	numerologyData, numErr := h.numerologyCache.GetAll()
	shadowData, shaErr := h.shadowCache.GetAll()
	if numErr != nil || shaErr != nil {
		analysisErr = fmt.Errorf("cache error: numErr=%v, shaErr=%v", numErr, shaErr)
		log.Printf("Error in GetSolarSystem (Analysis): %v", analysisErr)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not process request."})
	}

	decodedParts := service.DecodeName(name)
	var results []DecodedResult
	var totalNumerologyValue, totalShadowValue int
	var klakiniChars []string

	for _, thaiChar := range decodedParts {
		if thaiChar.IsThai {
			processComponent := func(charStr string) {
				if charStr == "" {
					return
				}
				numVal := numerologyData[charStr]
				shaVal := shadowData[charStr]

				isKlakini := false
				for _, r := range charStr {
					if h.klakiniCache.IsKlakini(day, r) {
						isKlakini = true
						break
					}
				}

				results = append(results, DecodedResult{charStr, numVal, shaVal, isKlakini})
				totalNumerologyValue += numVal
				totalShadowValue += shaVal

				if isKlakini && !contains(klakiniChars, charStr) {
					klakiniChars = append(klakiniChars, charStr)
				}
			}

			processComponent(thaiChar.Consonant)
			processComponent(thaiChar.Vowel)
			processComponent(thaiChar.ToneMark)
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
		"all_unique_pairs":       allUniquePairs,
	}

	sunDisplayChars := h.createDisplayChars(name, day)

	responseData := fiber.Map{
		"cleaned_name":       name,
		"input_day":          service.GetThaiDay(day),
		"allow_klakini":      allowKlakini,
		"SunDisplayNameHTML": sunDisplayChars,
	}
	for k, v := range analysisData {
		responseData[k] = v
	}

	return c.Render("partials/solar_system", responseData)
}

func (h *NumerologyHandler) GetSimilarNamesInitial(c *fiber.Ctx) error {
	return h.GetSimilarNames(c)
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1"
	allowKlakini := c.Query("allow_klakini") == "true" || c.Query("allow_klakini") == "on" || c.Query("allow_klakini") == "1"

	if name == "" {
		if isHtmxRequest(c) {
			return c.SendString("")
		}
		return c.JSON(fiber.Map{})
	}
	if day == "" {
		day = "sunday"
	}

	responseData := fiber.Map{
		"cleaned_name":  name,
		"input_day_raw": day,
		"is_auspicious": isAuspicious,
		"allow_klakini": allowKlakini,
	}

	return c.Render("decode", responseData)
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
