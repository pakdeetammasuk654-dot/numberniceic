package handler

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"numberniceic/internal/core/service"
	"numberniceic/views/analysis"
	"sort"
	"strconv"
	"strings"
	"unicode"

	"github.com/a-h/templ"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
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

func (h *NumerologyHandler) AnalyzeAPI(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if day == "" {
		day = "sunday"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"

	// --- VIP/Admin Detection via Token ---
	isVIP := false
	isAdmin := false

	authHeader := c.Get("Authorization")
	if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(jwtSecret), nil
		})

		if err == nil && token.Valid {
			if claims, ok := token.Claims.(jwt.MapClaims); ok {
				statusFloat, _ := claims["status"].(float64)
				status := int(statusFloat)
				if status == 2 || status == 9 {
					isVIP = true
				}
				if status == 9 {
					isAdmin = true
				}
			}
		}
	}
	// Also check locals just in case middleware set it
	if c.Locals("IsVIP") == true {
		isVIP = true
	}
	if c.Locals("IsAdmin") == true {
		isAdmin = true
	}
	// -------------------------------------

	repoAllowKlakini := !disableKlakini

	// 1. Get Solar System Data
	solarProps, err := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to get analysis"})
	}

	// 2. Get Similar Names
	disableKlakiniTable := disableKlakini
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on" || c.Query("disable_klakini_top4") == "1"
	repoAllowKlakini = !disableKlakiniTable || !disableKlakiniTop4

	similarNames, err := h.fetchSimilarNames(name, day, isAuspicious, repoAllowKlakini)
	if err == nil {
		h.calculateScoresAndHighlights(similarNames, day)
	}

	// 1. Prepare Table Candidates (Source of truth)
	tableCandidates := similarNames
	if disableKlakiniTable {
		tableCandidates = h.filterKlakiniNames(similarNames)
	}
	if len(tableCandidates) > 100 {
		tableCandidates = tableCandidates[:100]
	}

	// 2. Derive Top 4 and Last 4 - FETCH SEPARATELY (Turbo Mode)
	allowKlakiniTop4 := !disableKlakiniTop4
	bestCandidates, errBest := h.namesMiracleRepo.GetBestSimilarNames(name, day, 100, allowKlakiniTop4)
	if errBest == nil && len(bestCandidates) > 0 {
		h.calculateScoresAndHighlights(bestCandidates, day)
	} else {
		// Fallback: Use similarNames if Turbo fails or returns nothing
		bestCandidates = []domain.SimilarNameResult{}
		for _, n := range similarNames {
			if !n.HasBadPair && len(n.KlakiniChars) == 0 {
				if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
					continue
				}
				bestCandidates = append(bestCandidates, n)
			}
		}
	}

	top4, last4, _ := h.getBestNames(bestCandidates, 100)

	// 3. Apply Limit based on VIP/Admin status
	finalSimilarNames := tableCandidates
	if !isVIP && !isAdmin {
		if len(finalSimilarNames) > 3 {
			finalSimilarNames = finalSimilarNames[:3]
		}
	} else {
		// VIP/Admin can see up to 100
		if len(finalSimilarNames) > 100 {
			finalSimilarNames = finalSimilarNames[:100]
		}
	}

	return c.JSON(fiber.Map{
		"solar_system":        solarProps,
		"similar_names":       finalSimilarNames,
		"top_4_names":         top4,
		"last_4_names":        last4,
		"total_similar_count": len(similarNames),
		"is_vip":              isVIP,
		"is_admin":            isAdmin,
	})
}

func (h *NumerologyHandler) GetSampleNamesAPI(c *fiber.Ctx) error {
	samples, err := h.sampleNamesCache.GetAll()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch sample names"})
	}

	return c.JSON(samples)
}

func (h *NumerologyHandler) AnalyzeStreaming(c *fiber.Ctx) error {
	// Parse query params
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))

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
		day = "sunday"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on"
	disableKlakiniTable := disableKlakini
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on"
	repoAllowKlakini := !disableKlakiniTable || !disableKlakiniTop4

	isVIP := c.Locals("IsVIP") == true

	// Prepare minimal Props for Index (Render Shell Immediately)
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
		IsVIP:                 isVIP,
		HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
		SolarSystemInitial:    analysis.SolarSystemSkeleton(), // 🔥 Show Skeleton Immediately
	}

	// 1. Set Headers for Streaming
	c.Set("Content-Type", "text/html; charset=utf-8")
	c.Set("Transfer-Encoding", "chunked")
	c.Set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate")
	c.Set("Pragma", "no-cache")
	c.Set("Expires", "0")
	c.Set("X-Accel-Buffering", "no") // 🔥 TRICK: Tell Nginx not to buffer this response!

	c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		// Define a way to flush
		flush := func() {
			w.Flush()
		}

		// A. Create the lazy Results component
		lazyResults := templ.ComponentFunc(func(ctx context.Context, w2 io.Writer) error {
			// 1. Render Table Skeleton
			if err := analysis.Skeleton("streaming-skeleton").Render(ctx, w2); err != nil {
				return err
			}
			// Flush the Skeleton immediately so it appears along with the rest of the shell
			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				w.Flush()
			}

			// --- HEAVY LIFTING STARTS HERE (Progressive) ---

			// B. Calculate & Stream Solar System (Phase 1)
			solarProps, _ := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
			solarProps.DisableKlakini = disableKlakiniTable
			solarProps.SkipTrigger = true

			// Render Solar System and a script to swap it into the wrapper
			// We wrap it in a div that we will swap via JS
			fmt.Fprintf(w2, "<div id=\"solar-swap-content\" style=\"display:none;\">")
			analysis.SolarSystem(solarProps).Render(ctx, w2)
			fmt.Fprintf(w2, "</div>")
			fmt.Fprintf(w2, "<script>document.getElementById('solar-system-wrapper').innerHTML = document.getElementById('solar-swap-content').innerHTML; document.getElementById('solar-swap-content').remove();</script>")

			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				w.Flush()
			}

			// C. Fetch Actual Data for Table (Phase 2)
			similarNames, err := h.fetchSimilarNames(name, day, false, repoAllowKlakini)
			if err != nil {
				return nil
			}

			// Cap similarity at 99% if not exact match
			normalizedInput := strings.TrimSpace(name)
			for i := range similarNames {
				normalizedDbName := strings.TrimSpace(similarNames[i].ThName)
				if normalizedDbName != normalizedInput && similarNames[i].Similarity > 0.99 {
					similarNames[i].Similarity = 0.99
				}
			}

			// 2. Filter for BEST NAMES (Top 4 / Last 4)
			allowKlakiniTop4 := !disableKlakiniTop4
			bestCandidates, errBest := h.namesMiracleRepo.GetBestSimilarNames(name, day, 100, allowKlakiniTop4)
			if errBest == nil && len(bestCandidates) > 0 {
				h.calculateScoresAndHighlights(bestCandidates, day)
			} else {
				bestCandidates = []domain.SimilarNameResult{}
				for _, n := range similarNames {
					if !n.HasBadPair && len(n.KlakiniChars) == 0 {
						if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
							continue
						}
						bestCandidates = append(bestCandidates, n)
					}
				}
			}

			top4, last4, totalCountBest := h.getBestNames(bestCandidates, 100)

			// 3. Filter for TABLE
			tableCandidates := similarNames
			if isAuspicious {
				var filtered []domain.SimilarNameResult
				for _, n := range tableCandidates {
					if !n.HasBadPair {
						filtered = append(filtered, n)
					}
				}
				tableCandidates = filtered
			}
			if disableKlakiniTable {
				tableCandidates = h.filterKlakiniNames(tableCandidates)
			}
			if len(tableCandidates) > 100 {
				tableCandidates = tableCandidates[:100]
			}

			displayNameHTML := h.createDisplayChars(name, day)
			var klakiniChars []string
			for _, dc := range displayNameHTML {
				if dc.IsBad {
					klakiniChars = append(klakiniChars, dc.Char)
				}
			}

			tableProps := analysis.SimilarNamesProps{
				SimilarNames:          tableCandidates,
				Top4Names:             top4,
				Last4Names:            last4,
				TotalFilteredCount:    totalCountBest,
				IsAuspicious:          isAuspicious,
				DisableKlakini:        disableKlakiniTable,
				DisableKlakiniTop4:    disableKlakiniTop4,
				DisplayNameHTML:       displayNameHTML,
				HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
				KlakiniChars:          klakiniChars,
				CleanedName:           name,
				InputDay:              service.GetThaiDay(day),
				AnimateHeader:         true,
				IsVIP:                 isVIP,
			}

			// D. Render the Table and Swap Script
			if err := analysis.SimilarNamesTable(tableProps).Render(ctx, w2); err != nil {
				return err
			}
			if err := analysis.StreamScript("results").Render(ctx, w2); err != nil {
				return err
			}

			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				w.Flush()
			}
			return nil
		})

		indexProps.Results = lazyResults

		// Render Index (Page Shell)
		analysis.Index(indexProps).Render(context.Background(), w)
		flush() // 🔥 FLUSH IMMEDIATELY after shell render
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

// AnalyzeLinguisticallyAPI returns JSON for mobile apps
func (h *NumerologyHandler) AnalyzeLinguisticallyAPI(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	if name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Name is required"})
	}

	analysisRes, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Analysis failed"})
	}

	return c.JSON(fiber.Map{
		"name":     name,
		"analysis": analysisRes,
	})
}

// calculateScoresAndHighlights calculates scores and also generates the DisplayNameHTML for each name.
func (h *NumerologyHandler) calculateScoresAndHighlights(names []domain.SimilarNameResult, day string) {
	for i := range names {
		satMeanings, satPos, satNeg := getMeaningsAndScores(names[i].SatNum, h.numberPairCache)
		shaMeanings, shaPos, shaNeg := getMeaningsAndScores(names[i].ShaNum, h.numberPairCache)

		names[i].TotalScore = satPos + satNeg + shaPos + shaNeg

		// HasBadPair detection must match visual logic (Red circles)
		hasBad := false
		for _, m := range satMeanings {
			if service.IsBadPairType(m.Meaning.PairType) {
				hasBad = true
				break
			}
		}
		if !hasBad {
			for _, m := range shaMeanings {
				if service.IsBadPairType(m.Meaning.PairType) {
					hasBad = true
					break
				}
			}
		}
		names[i].HasBadPair = hasBad

		// Premium/TopTier Logic:
		// 1. Must NOT have any BAD pairs (R10, R7, R5)
		// 2. Must have AT LEAST ONE GOOD pair (D10, D8, D5)
		// Apply this check to both Numerology (Sat) and Shadow (Sha) pillars.

		isPillarStrictPremium := func(pairs []string) bool {
			if len(pairs) == 0 {
				return false
			}
			for _, p := range pairs {
				if m, ok := h.numberPairCache.GetMeaning(p); ok {
					if !service.IsGoodPairType(m.PairType) {
						fmt.Printf("DEBUG: %s Pair %s Type '%s' NOT Good\n", names[i].ThName, p, m.PairType)
						return false // Found non-Good pair (Neutral or Bad)
					}
				} else {
					fmt.Printf("DEBUG: %s Pair %s Unknown/Not Found in Cache\n", names[i].ThName, p)
					return false // Unknown pair is not Good
				}
			}
			return true
		}

		satP := isPillarStrictPremium(names[i].SatNum)
		shaP := isPillarStrictPremium(names[i].ShaNum)
		names[i].IsTopTier = satP && shaP
		if names[i].IsTopTier {
			fmt.Printf("DEBUG: PREMIUM FOUND: %s\n", names[i].ThName)
		}

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
	offset := 0
	batchSize := 200

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

	var auspiciousNames []domain.SimilarNameResult
	validCount := 0
	target := 100

	for {
		candidates, err := h.namesMiracleRepo.GetAuspiciousNames(name, preferredConsonant, day, batchSize, offset, repoAllowKlakini)
		if err != nil {
			return nil, fmt.Errorf("error fetching candidates at offset %d: %w", offset, err)
		}
		if len(candidates) == 0 {
			break
		}

		h.calculateScoresAndHighlights(candidates, day)

		for _, candidate := range candidates {
			if candidate.IsTopTier {
				auspiciousNames = append(auspiciousNames, candidate)
				if len(candidate.KlakiniChars) == 0 {
					validCount++
				}
			}
		}

		if validCount >= target {
			break
		}

		offset += len(candidates)
		if offset >= 20000 {
			break
		}
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
		currentStr := string(r)
		isBad := h.klakiniCache.IsKlakini(day, r)

		// Look ahead for combining marks (vowels, tone marks, etc.)
		// We loop to consume ALL consecutive combining marks to ensure the whole cluster stays together.
		for i+1 < len(runes) && (unicode.Is(unicode.Mn, runes[i+1]) || unicode.Is(unicode.Mc, runes[i+1]) || unicode.Is(unicode.Me, runes[i+1])) {
			i++ // Advance to the combining char
			combiningChar := runes[i]
			currentStr += string(combiningChar)

			// If any part of the cluster (base or mark) is Klakini, the whole cluster is displayed as Bad (Red)
			if h.klakiniCache.IsKlakini(day, combiningChar) {
				isBad = true
			}
		}

		result = append(result, domain.DisplayChar{Char: currentStr, IsBad: isBad})
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
	disableKlakiniTable := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on"

	// We allow klakini in repo fetch if AT LEAST ONE of the sections allows it.
	repoAllowKlakini := !disableKlakiniTable || !disableKlakiniTop4

	if name == "" || day == "" {
		return c.SendString("<!-- Missing parameters -->")
	}

	var similarNames []domain.SimilarNameResult
	var err error
	// Always fetch from the general fetcher to get a pool for both cards and table
	similarNames, err = h.fetchSimilarNames(name, day, false, repoAllowKlakini)

	if err != nil {
		log.Printf("Error getting names: %v", err)
		return c.SendString("<div>Error loading names.</div>")
	}

	// Cap similarity at 99% if not exact match
	normalizedInput := strings.TrimSpace(name)
	for i := range similarNames {
		normalizedDbName := strings.TrimSpace(similarNames[i].ThName)
		if normalizedDbName != normalizedInput && similarNames[i].Similarity > 0.99 {
			similarNames[i].Similarity = 0.99
		}
	}

	h.calculateScoresAndHighlights(similarNames, day)

	// 1. Prepare Table Candidates
	tableCandidates := similarNames
	if isAuspicious {
		// Table "Good Names Only" uses !HasBadPair (no red)
		var filtered []domain.SimilarNameResult
		for _, n := range tableCandidates {
			if !n.HasBadPair {
				filtered = append(filtered, n)
			}
		}
		tableCandidates = filtered
	}
	if disableKlakiniTable {
		tableCandidates = h.filterKlakiniNames(tableCandidates)
	}
	if len(tableCandidates) > 100 {
		tableCandidates = tableCandidates[:100]
	}

	// 2. Prepare Best Names Candidates - FETCH SEPARATELY (Turbo Mode)
	allowKlakiniTop4 := !disableKlakiniTop4
	bestCandidates, errBest := h.namesMiracleRepo.GetBestSimilarNames(name, day, 100, allowKlakiniTop4)
	if errBest == nil && len(bestCandidates) > 0 {
		h.calculateScoresAndHighlights(bestCandidates, day)
	} else {
		// Fallback: Use similarNames if Turbo fails or returns nothing
		bestCandidates = []domain.SimilarNameResult{}
		for _, n := range similarNames {
			if !n.HasBadPair && len(n.KlakiniChars) == 0 {
				if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
					continue
				}
				bestCandidates = append(bestCandidates, n)
			}
		}
	}

	top4, last4, totalCountBest := h.getBestNames(bestCandidates, 100)

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
	showTop4 := c.Query("show_top4") == "true" || c.Query("show_top4") == "on"

	props := analysis.SimilarNamesProps{
		SimilarNames:          tableCandidates,
		Top4Names:             top4,
		Last4Names:            last4,
		TotalFilteredCount:    totalCountBest,
		IsAuspicious:          isAuspicious,
		DisableKlakini:        disableKlakiniTable,
		DisableKlakiniTop4:    disableKlakiniTop4,
		DisplayNameHTML:       displayNameHTML,
		HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
		KlakiniChars:          klakiniChars,
		CleanedName:           name,
		InputDay:              service.GetThaiDay(day),
		AnimateHeader:         false,
		IsVIP:                 isVIP,
		ShowTop4:              showTop4,
	}

	section := c.Query("section")
	if section == "top4" {
		return templ_render.Render(c, analysis.Top4Section(props))
	} else if section == "table" {
		return templ_render.Render(c, analysis.SimilarNamesList(props))
	}

	return templ_render.Render(c, analysis.SimilarNamesTable(props))
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

func (h *NumerologyHandler) getBestNames(candidates []domain.SimilarNameResult, limit int) ([]domain.SimilarNameResult, []domain.SimilarNameResult, int) {
	var top4 []domain.SimilarNameResult
	var last4 []domain.SimilarNameResult

	// 1. Filter for "Strict Best" (IsTopTier - All Green)
	var bestNames []domain.SimilarNameResult
	// 2. Also track "Standard Good" (No Bad Pairs, No Klakini) as backup
	var standardGoodNames []domain.SimilarNameResult

	for _, c := range candidates {
		// Basic requirement: No Bad Pairs, No Klakini
		// (Note: candidates passed here usually already filter Klakini if requested,
		// but let's double check HasBadPair which is the baseline for "Good")
		if !c.HasBadPair && len(c.KlakiniChars) == 0 {
			if c.IsTopTier {
				bestNames = append(bestNames, c)
			} else {
				standardGoodNames = append(standardGoodNames, c)
			}
		}
	}

	// 3. Fill the list: Prioritize Best, then fill with Standard Good
	finalList := bestNames
	if len(finalList) < limit {
		needed := limit - len(finalList)
		if len(standardGoodNames) > 0 {
			// Take as many standard ones as needed
			take := needed
			if take > len(standardGoodNames) {
				take = len(standardGoodNames)
			}
			finalList = append(finalList, standardGoodNames[:take]...)
		}
	}

	// 4. Limit to requested size
	if len(finalList) > limit {
		finalList = finalList[:limit]
	}

	// 5. Derive Top 4 and Last 4
	if len(finalList) > 0 {
		// Get Top 4
		if len(finalList) >= 4 {
			top4 = finalList[:4]
		} else {
			top4 = finalList
		}

		// Get Last 4 from the end of this ranked set
		if len(finalList) >= 4 {
			last4 = finalList[len(finalList)-4:]
		} else {
			last4 = finalList
		}
	}

	return top4, last4, len(finalList)
}

func (h *NumerologyHandler) filterKlakiniNames(names []domain.SimilarNameResult) []domain.SimilarNameResult {
	var filtered []domain.SimilarNameResult
	for _, n := range names {
		// If len(KlakiniChars) > 0, it means it has klakini.
		// Since highlights are already calculated, we can check KlakiniChars field.
		if len(n.KlakiniChars) == 0 {
			filtered = append(filtered, n)
		}
	}
	// Note: h.calculateScoresAndHighlights MUST be called before this.
	return filtered
}

func (h *NumerologyHandler) fetchSimilarNames(name, day string, isAuspicious, repoAllowKlakini bool) ([]domain.SimilarNameResult, error) {
	if isAuspicious {
		// Use the specific auspicious finder (starts with same letter logic)
		return h.findAuspiciousNames(name, day, repoAllowKlakini)
	}

	// Original Logic: Loop to find enough "Perfectly Good" names (No Bad Pair AND No Klakini)
	var accumulatedNames []domain.SimilarNameResult
	offset := 0
	batchSize := 200
	targetGood := 100
	validCount := 0

	for {
		batch, err := h.namesMiracleRepo.GetSimilarNames(name, day, batchSize, offset, repoAllowKlakini)
		if err != nil {
			return nil, err
		}
		if len(batch) == 0 {
			break
		}

		h.calculateScoresAndHighlights(batch, day)

		for _, n := range batch {
			// If we are in "Similar Names" mode (isAuspicious=false),
			// we collect ALL names for the table, but we still count how many
			// "Perfectly Good" names we have to ensure we have enough for ranking cards.
			accumulatedNames = append(accumulatedNames, n)

			if !n.HasBadPair && len(n.KlakiniChars) == 0 {
				validCount++
			}
		}

		if validCount >= targetGood {
			break
		}

		offset += len(batch)
		if offset >= 20000 { // Failsafe to prevent infinite loop
			break
		}
	}

	return accumulatedNames, nil
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
		InputDayRaw:          service.GetThaiDay(day),
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
