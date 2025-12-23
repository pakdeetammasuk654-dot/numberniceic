package handler

import (
	"fmt"
	"log"
	"net/http"
	"net/url"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"numberniceic/internal/core/service"
	"sort"
	"strconv"
	"strings"
	"unicode"

	"bufio"
	"context"
	"io"
	"numberniceic/views/analysis"

	"github.com/a-h/templ"
	"github.com/gofiber/fiber/v2"
)

const PageSize = 100
const SearchBatchSize = 200

// Struct definitions

type NumerologyHandler struct {
	numerologyCache   *cache.NumerologyCache
	shadowCache       *cache.NumerologyCache
	klakiniCache      *cache.KlakiniCache
	numberPairCache   *cache.NumberPairCache
	namesMiracleRepo  ports.NamesMiracleRepository
	linguisticService *service.LinguisticService
	sampleNamesCache  *cache.SampleNamesCache
}

func NewNumerologyHandler(
	numCache, shaCache *cache.NumerologyCache,
	klaCache *cache.KlakiniCache,
	pairCache *cache.NumberPairCache,
	namesRepo ports.NamesMiracleRepository,
	lingoService *service.LinguisticService,
	sampleCache *cache.SampleNamesCache,
) *NumerologyHandler {
	return &NumerologyHandler{
		numerologyCache:   numCache,
		shadowCache:       shaCache,
		klakiniCache:      klaCache,
		numberPairCache:   pairCache,
		namesMiracleRepo:  namesRepo,
		linguisticService: lingoService,
		sampleNamesCache:  sampleCache,
	}
}

func isHtmxRequest(c *fiber.Ctx) bool {
	return c.Get("HX-Request") == "true"
}

func (h *NumerologyHandler) AnalyzeStreaming(c *fiber.Ctx) error {
	// Parse query params
	name := c.Query("name")
	day := c.Query("day")

	// Get Sample Names
	samples, _ := h.sampleNamesCache.GetAll()

	if name == "" {
		if len(samples) > 0 {
			name = samples[0].Name
		} else {
			name = "ปัญญา"
		}
	}

	if day == "" {
		day = "SUNDAY"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on"
	repoAllowKlakini := !disableKlakini

	isVIP := c.Locals("IsVIP") == true

	// Prepare Solar System Data (Synchronous/Fast)
	solarProps, _ := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakini
	solarProps.SkipTrigger = true

	// Prepare Props for Index
	indexProps := analysis.IndexProps{
		Layout: analysis.LayoutProps{
			Title:        fmt.Sprintf("วิเคราะห์ชื่อ %s ผลรวมเลขศาสตร์ พลังเงา", name),
			Description:  fmt.Sprintf("ผลวิเคราะห์ชื่อ %s สำหรับผู้ที่เกิดวัน %s วิเคราะห์คะแนนเลขศาสตร์และพลังเงา พร้อมตรวจสอบอักษรกาลกิณีอย่างละเอียด", name, service.GetThaiDay(day)),
			Keywords:     fmt.Sprintf("วิเคราะห์ชื่อ %s, ชื่อมงคล %s, เลขศาสตร์ %s, พลังเงา %s", name, name, name, name),
			Canonical:    fmt.Sprintf("https://xn--b3cu8e7ah6h.com/analyzer?name=%s&day=%s", url.QueryEscape(name), url.QueryEscape(day)),
			OGImage:      "https://xn--b3cu8e7ah6h.com/static/og-analyzer.png",
			OGType:       "website",
			IsLoggedIn:   c.Locals("IsLoggedIn") == true,
			IsAdmin:      c.Locals("IsAdmin") == true,
			ActivePage:   "analyzer",
			ToastSuccess: c.Locals("toast_success"),
			ToastError:   c.Locals("toast_error"),
			IsVIP:        isVIP,
		},
		DefaultName:           name,
		DefaultDay:            day,
		SampleNames:           samples,
		SolarSystem:           solarProps,
		IsVIP:                 isVIP,
		HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
	}

	// 1. Set Headers for Streaming
	c.Set("Content-Type", "text/html; charset=utf-8")
	c.Set("Transfer-Encoding", "chunked")
	c.Set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate")
	c.Set("Pragma", "no-cache")
	c.Set("Expires", "0")
	c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		// Create a "Lazy Component" that acts as the Results prop
		lazyResults := templ.ComponentFunc(func(ctx context.Context, w2 io.Writer) error {
			// A. Render Skeleton first
			if err := analysis.Skeleton("streaming-skeleton").Render(ctx, w2); err != nil {
				return err
			}

			// B. Flush to send Skeleton to client
			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				// Try flushing the underlying writer if possible,
				// but w2 here is passed from templ.Render.
				// In this context, w2 IS the bufio.Writer from Fiber (wrapped).
				// We can try to cast w2 back to *bufio.Writer or flush it if it's a flusher.
				// Since we are inside BodyStreamWriter, 'w' is the bufio writer.
				// 'w2' should be wrapping it.
				// We can just flush 'w' directly if we are sure content is written to it.
				w.Flush()
			}

			// C. Simulate Delay / Computation
			// time.Sleep(1 * time.Second) // Optional: Simulate lag to see skeleton

			// D. Fetch Actual Data
			similarNames, err := h.fetchSimilarNames(name, day, isAuspicious, repoAllowKlakini)

			if err != nil {
				// Render Error
				return nil
			}

			h.calculateScoresAndHighlights(similarNames, day)
			displayNameHTML := h.createDisplayChars(name, day)
			var klakiniChars []string
			for _, dc := range displayNameHTML {
				if dc.IsBad {
					klakiniChars = append(klakiniChars, dc.Char)
				}
			}
			// --- Logic End ---

			// E. Render Actual Table
			tableProps := analysis.SimilarNamesProps{
				SimilarNames:          similarNames,
				IsAuspicious:          isAuspicious,
				DisableKlakini:        disableKlakini,
				DisplayNameHTML:       displayNameHTML,
				HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day), // Add this line
				KlakiniChars:          klakiniChars,
				CleanedName:           name,
				InputDay:              service.GetThaiDay(day),
				AnimateHeader:         true,
				IsVIP:                 isVIP,
			}

			// F. Render the "Swapping" Logic
			// We have rendered the Skeleton. Now we append the Table AND a script to replace the Skeleton.
			// Actually, if we just append the table, it appears below.
			// We want to replace #results content or #similar-names-skeleton.
			// My StreamScript removes the skeleton.
			// And the Table renders a div with id="similar-names-section".
			// Visual: [Skeleton] ... [Table]
			// Script: removes Skeleton.
			// Result: [Table]

			if err := analysis.SimilarNamesTable(tableProps).Render(ctx, w2); err != nil {
				return err
			}
			if err := analysis.StreamScript("results").Render(ctx, w2); err != nil {
				return err
			}

			w.Flush()
			return nil
		})

		indexProps.Results = lazyResults

		// Render the whole page. When it hits 'Results', it executes the lazy component.
		analysis.Index(indexProps).Render(context.Background(), w)
		w.Flush()
	})

	return nil
}

// AnalyzeLinguistically analyzes the name using the linguistic service and renders the result.
func (h *NumerologyHandler) AnalyzeLinguistically(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	if name == "" {
		return c.Status(fiber.StatusBadRequest).SendString("Name parameter is required.")
	}

	analysisRes, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		log.Printf("Error from linguistic service: %v", err)
		return c.Status(fiber.StatusInternalServerError).SendString("Failed to analyze name linguistically.")
	}

	return templ_render.Render(c, analysis.LinguisticModal(name, analysisRes))
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

	return templ_render.Render(c, analysis.NumberMeaningsModal(meanings))
}

// calculateScoresAndHighlights calculates scores and also generates the DisplayNameHTML for each name.
func (h *NumerologyHandler) calculateScoresAndHighlights(names []domain.SimilarNameResult, day string) {
	for i := range names {
		satMeanings, satPos, satNeg := getMeaningsAndScores(names[i].SatNum, h.numberPairCache)
		shaMeanings, shaPos, shaNeg := getMeaningsAndScores(names[i].ShaNum, h.numberPairCache)
		names[i].TotalScore = satPos + satNeg + shaPos + shaNeg
		names[i].IsTopTier = h.isAllPairsTopTier(names[i].ThName, names[i].SatNum, h.numberPairCache) &&
			h.isAllPairsTopTier(names[i].ThName, names[i].ShaNum, h.numberPairCache)

		// Generate display characters for the name with true Klakini status.
		names[i].DisplayNameHTML = h.createDisplayChars(names[i].ThName, day)

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

func (h *NumerologyHandler) findAuspiciousNames(name, day string, repoAllowKlakini bool) ([]domain.SimilarNameResult, error) {
	var auspiciousNames []domain.SimilarNameResult
	offset := 0

	// Determine the best consonant to use for sorting/prioritizing
	preferredConsonant := h.findBestConsonant(name, day)
	if repoAllowKlakini {
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
		candidates, err := h.namesMiracleRepo.GetAuspiciousNames(name, preferredConsonant, day, SearchBatchSize, offset, repoAllowKlakini)
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
	var result []domain.DisplayChar
	runes := []rune(name)

	for i := 0; i < len(runes); i++ {
		r := runes[i]
		char := string(r)
		isBad := h.klakiniCache.IsKlakini(day, r)

		// Check if the next character is a combining mark
		if i+1 < len(runes) && unicode.Is(unicode.Mn, runes[i+1]) {
			combiningChar := runes[i+1]
			isCombiningBad := h.klakiniCache.IsKlakini(day, combiningChar)

			// If the base is not bad, but the combining mark is
			if !isBad && isCombiningBad {
				// Add the base character as good
				result = append(result, domain.DisplayChar{Char: char, IsBad: false})
				// Add the combining mark as bad
				result = append(result, domain.DisplayChar{Char: string(combiningChar), IsBad: true})
				i++ // Skip the combining mark in the next iteration
				continue
			}
		}

		// Default behavior: add the character with its own klakini status
		result = append(result, domain.DisplayChar{Char: char, IsBad: isBad})
	}

	return result
}

// createHeaderDisplayChars returns characters for the header where a Klakini combining mark
// is merged with its preceding base consonant so that the span wraps both characters.
func (h *NumerologyHandler) createHeaderDisplayChars(name, day string) []domain.DisplayChar {
	return h.createDisplayChars(name, day) // Use the same logic for now
}

func (h *NumerologyHandler) GetSimilarNames(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"
	repoAllowKlakini := !disableKlakini

	if name == "" || day == "" {
		return c.SendString("<!-- Missing parameters -->")
	}

	var similarNames []domain.SimilarNameResult
	var err error
	if isAuspicious {
		similarNames, err = h.findAuspiciousNames(name, day, repoAllowKlakini)
	} else {
		similarNames, err = h.namesMiracleRepo.GetSimilarNames(name, day, PageSize, 0, repoAllowKlakini)
		if err == nil && len(similarNames) < PageSize {
			needed := PageSize - len(similarNames)
			excludedIDs := make([]int, len(similarNames))
			for i, n := range similarNames {
				excludedIDs[i] = n.NameID
			}

			preferredConsonant := h.findBestConsonant(name, day)
			if repoAllowKlakini {
				for _, r := range name {
					if r != 'เ' && r != 'แ' && r != 'โ' && r != 'ใ' && r != 'ไ' {
						preferredConsonant = string(r)
						break
					}
				}
			}

			fallbackNames, fallbackErr := h.namesMiracleRepo.GetFallbackNames(name, preferredConsonant, day, needed, repoAllowKlakini, excludedIDs)
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

	// Use Templ Component
	isVIP := c.Locals("IsVIP") == true
	props := analysis.SimilarNamesProps{
		SimilarNames:          similarNames,
		IsAuspicious:          isAuspicious,
		DisableKlakini:        disableKlakini,
		DisplayNameHTML:       displayNameHTML,
		HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day), // Add this line
		KlakiniChars:          klakiniChars,
		CleanedName:           name,
		InputDay:              service.GetThaiDay(day),
		AnimateHeader:         false,
		IsVIP:                 isVIP,
	}

	c.Set("Content-Type", "text/html")
	return analysis.SimilarNamesTable(props).Render(c.Context(), c.Response().BodyWriter())
}

func (h *NumerologyHandler) GetAuspiciousNames(c *fiber.Ctx) error {
	return h.GetSimilarNames(c)
}

func (h *NumerologyHandler) GetSolarSystem(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"

	isVIP := c.Locals("IsVIP") == true
	repoAllowKlakini := !disableKlakini
	props, err := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading data")
	}

	return templ_render.Render(c, analysis.SolarSystem(props))
}

func (h *NumerologyHandler) GetSimilarNamesInitial(c *fiber.Ctx) error {
	return h.GetSimilarNames(c)
}

func (h *NumerologyHandler) Decode(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"

	if name == "" {
		if isHtmxRequest(c) {
			return c.SendString("")
		}
		return c.JSON(fiber.Map{})
	}
	if day == "" {
		day = "sunday"
	}

	isVIP := c.Locals("IsVIP") == true

	// Calculate Solar System Props (Fast)
	solarProps, _ := h.getSolarSystemProps(name, day, !disableKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakini

	return templ_render.Render(c, analysis.SolarSystem(solarProps))
}

func (h *NumerologyHandler) fetchSimilarNames(name, day string, isAuspicious, repoAllowKlakini bool) ([]domain.SimilarNameResult, error) {
	if isAuspicious {
		return h.findAuspiciousNames(name, day, repoAllowKlakini)
	}

	similarNames, err := h.namesMiracleRepo.GetSimilarNames(name, day, PageSize, 0, repoAllowKlakini)
	if err != nil {
		return nil, err
	}

	if len(similarNames) < PageSize {
		needed := PageSize - len(similarNames)
		excludedIDs := make([]int, len(similarNames))
		for i, n := range similarNames {
			excludedIDs[i] = n.NameID
		}

		preferredConsonant := h.findBestConsonant(name, day)
		if repoAllowKlakini {
			for _, r := range name {
				if r != 'เ' && r != 'แ' && r != 'โ' && r != 'ใ' && r != 'ไ' {
					preferredConsonant = string(r)
					break
				}
			}
		}
		fallbackNames, fallbackErr := h.namesMiracleRepo.GetFallbackNames(name, preferredConsonant, day, needed, repoAllowKlakini, excludedIDs)
		if fallbackErr == nil {
			similarNames = append(similarNames, fallbackNames...)
		}
	}
	return similarNames, nil
}

func getMeaningsAndScores(pairs []string, pairCache *cache.NumberPairCache) ([]domain.PairMeaningResult, int, int) {
	var meanings []domain.PairMeaningResult
	var posScore, negScore int
	for _, p := range pairs {
		if meaning, ok := pairCache.GetMeaning(p); ok {
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

func contains(slice []string, item string) bool {
	for _, a := range slice {
		if a == item {
			return true
		}
	}
	return false
}

func (h *NumerologyHandler) getSolarSystemProps(name, day string, repoAllowKlakini bool, isVIP bool) (analysis.SolarSystemProps, error) {

	decodedParts := service.DecodeName(name)
	var results []domain.DecodedResult
	var totalNumerologyValue, totalShadowValue int
	var klakiniChars []string

	for _, thaiChar := range decodedParts {
		if thaiChar.IsThai {
			processComponent := func(charStr string) {
				if charStr == "" {
					return
				}
				numVal, _ := h.numerologyCache.GetValue(charStr)
				shaVal, _ := h.shadowCache.GetValue(charStr)

				isKlakini := false
				for _, r := range charStr {
					if h.klakiniCache.IsKlakini(day, r) {
						isKlakini = true
						break
					}
				}

				results = append(results, domain.DecodedResult{Character: charStr, NumerologyValue: numVal, ShadowValue: shaVal, IsKlakini: isKlakini})
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

	var allUniquePairs []domain.PairMeaningResult
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

	return analysis.SolarSystemProps{
		CleanedName:          name,
		InputDay:             service.GetThaiDay(day),
		InputDayRaw:          day,
		DisableKlakini:       !repoAllowKlakini,
		SunDisplayNameHTML:   h.createDisplayChars(name, day),
		NumerologyPairs:      numMeanings,
		ShadowPairs:          shaMeanings,
		NumPositiveScore:     numPos,
		NumNegativeScore:     numNeg,
		ShaPositiveScore:     shaPos,
		ShaNegativeScore:     shaNeg,
		GrandTotalScore:      grandTotalScore,
		IsSunDead:            grandTotalScore < 0,
		AllUniquePairs:       allUniquePairs,
		DecodedParts:         results,
		TotalNumerologyValue: totalNumerologyValue,
		TotalShadowValue:     totalShadowValue,
		IsVIP:                isVIP,
	}, nil
}
