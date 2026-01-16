package handler

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
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
	"time"
	"unicode"

	"github.com/a-h/templ"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

const PageSize = 100
const SearchBatchSize = 200

// Struct definitions

type NumerologyHandler struct {
	numerologyCache     *cache.NumerologyCache
	shadowCache         *cache.NumerologyCache
	klakiniCache        *cache.KlakiniCache
	numberPairCache     *cache.NumberPairCache
	numberCategoryCache *cache.NumberCategoryCache
	namesMiracleRepo    ports.NamesMiracleRepository
	linguisticService   *service.LinguisticService
	sampleNamesCache    *cache.SampleNamesCache
	phoneNumberService  *service.PhoneNumberService
	db                  *sql.DB
}

func NewNumerologyHandler(
	numCache, shaCache *cache.NumerologyCache,
	klaCache *cache.KlakiniCache,
	pairCache *cache.NumberPairCache,
	categoryCache *cache.NumberCategoryCache,
	namesRepo ports.NamesMiracleRepository,
	lingoService *service.LinguisticService,
	sampleCache *cache.SampleNamesCache,
	phoneNumberService *service.PhoneNumberService,
	db *sql.DB,
) *NumerologyHandler {
	return &NumerologyHandler{
		numerologyCache:     numCache,
		shadowCache:         shaCache,
		klakiniCache:        klaCache,
		numberPairCache:     pairCache,
		numberCategoryCache: categoryCache,
		namesMiracleRepo:    namesRepo,
		linguisticService:   lingoService,
		sampleNamesCache:    sampleCache,
		phoneNumberService:  phoneNumberService,
		db:                  db,
	}
}

func isHtmxRequest(c *fiber.Ctx) bool {
	return c.Get("HX-Request") == "true"
}

func (h *NumerologyHandler) AnalyzePhoneNumberAPI(c *fiber.Ctx) error {
	number := c.Query("number")
	if number == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Number is required"})
	}

	mainPairs, hiddenPairs, sumMeaning := h.phoneNumberService.AnalyzeRawNumber(number)

	// Combine all pairs for category analysis
	var allPairs []string
	for _, p := range mainPairs {
		allPairs = append(allPairs, p.Pair)
	}
	for _, p := range hiddenPairs {
		allPairs = append(allPairs, p.Pair)
	}

	// Calculate Category counts & Breakdown
	counts := map[string]int{
		"การงาน":  0,
		"การเงิน": 0,
		"ความรัก": 0,
		"สุขภาพ":  0,
	}

	breakdown := make(map[string]domain.CategoryBreakdown)
	for cat := range counts {
		color := "#A0A0A0"
		switch cat {
		case "การงาน":
			color = "#90CAF9"
		case "การเงิน":
			color = "#FFCC80"
		case "ความรัก":
			color = "#F48FB1"
		case "สุขภาพ":
			color = "#80CBC4"
		}
		breakdown[cat] = domain.CategoryBreakdown{Good: 0, Bad: 0, Color: color}
	}

	allowedCategories := map[string]bool{
		"การงาน":  true,
		"การเงิน": true,
		"ความรัก": true,
		"สุขภาพ":  true,
	}

	categoryKeywords := make(map[string]map[string]bool)
	for cat := range counts {
		categoryKeywords[cat] = make(map[string]bool)
	}

	for _, pairNumber := range allPairs {
		if cats, ok := h.numberCategoryCache.GetCategories(pairNumber); ok {
			keywords := h.numberCategoryCache.GetKeywords(pairNumber)
			for _, c := range cats {
				if !allowedCategories[c] {
					continue
				}
				counts[c]++ // Update count

				numberType := h.numberCategoryCache.GetNumberType(pairNumber)
				current := breakdown[c]
				if numberType == "ดี" {
					current.Good++
				} else if numberType == "ร้าย" {
					current.Bad++
				}

				for _, kw := range keywords {
					if kw != "" {
						categoryKeywords[c][kw] = true
					}
				}
				breakdown[c] = current
			}
		}
	}

	// Consolidate keywords
	for cat, kwMap := range categoryKeywords {
		if entry, exists := breakdown[cat]; exists {
			var kws []string
			for kw := range kwMap {
				kws = append(kws, kw)
			}
			sort.Strings(kws)
			entry.Keywords = kws
			breakdown[cat] = entry
		}
	}

	// Calculate Weighted Score based on User Request
	// 1. Phone A (Main Pairs) - 55%
	//    Pair 1: 5%, Pair 2: 5%, Pair 3: 10%, Pair 4: 15%, Pair 5: 20%
	// 2. Phone B (Hidden Pairs) - 25%
	//    Pair 1: 3%, Pair 2: 5%, Pair 3: 5%, Pair 4: 12%
	// 3. Sum - 20%
	
	totalScore := 0.0

	// Weights for Main Pairs
	mainWeights := []float64{0.05, 0.05, 0.10, 0.15, 0.20}
	for i, pair := range mainPairs {
		if i < len(mainWeights) {
			totalScore += float64(pair.Meaning.PairPoint) * mainWeights[i]
		}
	}

	// Weights for Hidden Pairs
	hiddenWeights := []float64{0.03, 0.05, 0.05, 0.12}
	for i, pair := range hiddenPairs {
		if i < len(hiddenWeights) {
			totalScore += float64(pair.Meaning.PairPoint) * hiddenWeights[i]
		}
	}

	// Sum Weight
	totalScore += float64(sumMeaning.Meaning.PairPoint) * 0.20

	return c.JSON(fiber.Map{
		"number":             number,
		"main_pairs":         mainPairs,
		"hidden_pairs":       hiddenPairs,
		"sum_meaning":        sumMeaning,
		"category_breakdown": breakdown,
		"total_percent":      totalScore,
	})
}

func (h *NumerologyHandler) AnalyzeAPI(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if day == "" {
		day = strings.ToLower(strings.TrimSpace(c.Query("birth_day")))
	}
	if day == "" {
		day = "thursday"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1" ||
		c.Query("is_auspicious") == "true" || c.Query("is_auspicious") == "on" || c.Query("is_auspicious") == "1"
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

	section := c.Query("section") // "solar" or "names" or empty (all)

	// 1. Get Solar System Data (Fast)
	var solarProps interface{}
	if section == "" || section == "solar" {
		props, err := h.getSolarSystemProps(name, day, !disableKlakini, isVIP)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to get analysis"})
		}
		solarProps = props
		if section == "solar" {
			return c.JSON(fiber.Map{
				"solar_system": solarProps,
				"is_vip":       isVIP,
				"is_admin":     isAdmin,
			})
		}
	}

	// 2. Get Similar Names & Best Names (Slower)
	var similarNames []domain.SimilarNameResult
	var totalBest int
	var top4, last4 []domain.SimilarNameResult
	var finalSimilarNames []domain.SimilarNameResult
	var bestNamesTop4, bestNamesRecommended []fiber.Map
	var titleRec string
	var tableCandidates []domain.SimilarNameResult

	if section == "" || section == "names" {
		disableKlakiniTable := disableKlakini
		disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on" || c.Query("disable_klakini_top4") == "1"
		repoAllowKlakini := !disableKlakiniTable || !disableKlakiniTop4

		// Increase limit to support frontend pagination (VIP only or higher default)
		maxLimit_internal := 100
		if isVIP || isAdmin {
			maxLimit_internal = 1000
		}
		if qLimit := c.Query("limit"); qLimit != "" {
			if val, err := strconv.Atoi(qLimit); err == nil && val > 0 && val <= 1000 {
				maxLimit_internal = val
			}
		}

		var err error
		similarNames, err = h.fetchSimilarNames(name, day, isAuspicious, repoAllowKlakini, maxLimit_internal, nil)
		if err == nil {
			// Cap similarity at 99% if not exact match (Fix for "100%" confusion on similar phonetics)
			normalizedInput := strings.TrimSpace(name)
			for i := range similarNames {
				normalizedDbName := strings.TrimSpace(similarNames[i].ThName)
				if normalizedDbName != normalizedInput && similarNames[i].Similarity > 0.99 {
					similarNames[i].Similarity = 0.99
				}
			}

			h.calculateScoresAndHighlights(similarNames, day)
		}

		// 1. Prepare Table Candidates (Source of truth)
		tableCandidates = similarNames
		if disableKlakiniTable {
			tableCandidates = h.filterKlakiniNames(similarNames)
		}
		if len(tableCandidates) > maxLimit_internal {
			tableCandidates = tableCandidates[:maxLimit_internal]
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
				if !n.HasBadPair {
					if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
						continue
					}
					bestCandidates = append(bestCandidates, n)
				}
			}
		}

		top4, last4, _, totalBest = h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

		if !isAuspicious {
			log.Printf("DEBUG: !isAuspicious mode. tableCandidates count: %d", len(tableCandidates))
			hasBad := false
			for _, n := range tableCandidates {
				if n.HasBadPair {
					hasBad = true
					break
				}
			}
			log.Printf("DEBUG: !isAuspicious mode. Has any Bad Pair Name? %v", hasBad)
		}

		// 3. Apply Limit based on VIP/Admin status or requested limit
		limit := 3
		if isVIP || isAdmin {
			limit = 1000 // Increased for pagination support
		}
		// Allow explicit limit request (max 1000)
		if qLimit := c.Query("limit"); qLimit != "" {
			if val, err := strconv.Atoi(qLimit); err == nil && val > 0 && val <= 1000 {
				limit = val
			}
		}

		finalSimilarNames = tableCandidates
		if len(finalSimilarNames) > limit {
			finalSimilarNames = finalSimilarNames[:limit]
		}

		// 4. Prepare Simplified Best Names for UI
		formatBestNames := func(names []domain.SimilarNameResult, startRank int, isDescending bool) []fiber.Map {
			var result []fiber.Map
			for i, n := range names {
				rank := startRank + i
				if isDescending {
					rank = totalBest - (len(names) - 1 - i)
				}
				result = append(result, fiber.Map{
					"th_name":           n.ThName,
					"rank":              rank,
					"display_name_html": n.DisplayNameHTML,
					"total_score":       n.TotalScore,
					"similarity":        n.Similarity,
					"is_top_tier":       n.IsTopTier,
					"sat_num":           n.SatNum,
					"sha_num":           n.ShaNum,
					"t_sat":             n.TSat,
					"t_sha":             n.TSha,
				})
			}
			return result
		}

		bestNamesTop4 = formatBestNames(top4, 1, false)
		bestNamesRecommended = formatBestNames(last4, totalBest-len(last4)+1, true)

		// Determine recommended title range
		startRec := totalBest - len(last4) + 1
		if startRec < 1 {
			startRec = 1
		}
		titleRec = fmt.Sprintf("แนะนำชื่อดีที่สุดลำดับ %d - %d สำหรับ ", startRec, totalBest)
	}

	resp := fiber.Map{
		"similar_names":        finalSimilarNames,
		"total_similar_count":  len(similarNames),
		"is_vip":               isVIP,
		"is_admin":             isAdmin,
		"top_4_names":          top4,
		"last_4_names":         last4,
		"total_filtered_count": totalBest,
		"best_names": fiber.Map{
			"target_name_html":         h.createDisplayChars(name, day),
			"total_count":              totalBest,
			"top_4":                    bestNamesTop4,
			"recommended":              bestNamesRecommended,
			"title_prefix_top4":        "4 อันดับชื่อที่ดีที่สุดสำหรับ ",
			"title_prefix_recommended": titleRec,
		},
	}

	if section == "" {
		resp["solar_system"] = solarProps
	}

	return c.JSON(resp)
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
	if day == "" {
		day = strings.ToLower(strings.TrimSpace(c.Query("birth_day")))
	}

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
		day = "thursday"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" ||
		c.Query("is_auspicious") == "true" || c.Query("is_auspicious") == "on"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on"
	disableKlakiniTable := disableKlakini
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on"
	repoAllowKlakini := !disableKlakiniTable // Main search should respect table toggle for accurate progress reporting

	isVIP := c.Locals("IsVIP") == true
	isAdmin := c.Locals("IsAdmin") == true

	// Calculate Solar System Props (needed for visualization)
	log.Printf("⏱️  [PERF] Starting getSolarSystemProps for name: %s", name)
	startSolar := time.Now()
	solarProps, _ := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakiniTable
	solarProps.SkipTrigger = true
	log.Printf("✅ [PERF] getSolarSystemProps completed in: %v", time.Since(startSolar))

	// Prepare minimal Props for Index (Render Shell Immediately)
	indexProps := analysis.IndexProps{
		Layout: analysis.LayoutProps{
			Title:              fmt.Sprintf("วิเคราะห์ชื่อ %s ผลรวมเลขศาสตร์ พลังเงา", name),
			Description:        fmt.Sprintf("ผลวิเคราะห์ชื่อ %s สำหรับผู้ที่เกิดวัน %s วิเคราะห์คะแนนเลขศาสตร์และพลังเงา พร้อมตรวจสอบอักษรกาลกิณีอย่างละเอียด", name, service.GetThaiDay(day)),
			Keywords:           fmt.Sprintf("วิเคราะห์ชื่อ %s, ชื่อมงคล %s, เลขศาสตร์ %s, พลังเงา %s", name, name, name, name),
			Canonical:          fmt.Sprintf("https://xn--b3cu8e7ah6h.com/analyzer?name=%s&day=%s", url.QueryEscape(name), url.QueryEscape(day)),
			OGImage:            "https://xn--b3cu8e7ah6h.com/static/og-analyzer.png",
			OGType:             "website",
			IsLoggedIn:         c.Locals("IsLoggedIn") == true,
			IsAdmin:            c.Locals("IsAdmin") == true,
			ActivePage:         "analyzer",
			ToastSuccess:       c.Locals("toast_success"),
			ToastError:         c.Locals("toast_error"),
			IsVIP:              isVIP,
			HasShippingAddress: true, // Suppress notification on analyzer page for now
			AvatarURL:          func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		},
		DefaultName:           name,
		DefaultDay:            strings.ToUpper(day),
		SampleNames:           samples,
		IsVIP:                 isVIP,
		HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
		SolarSystem:           solarProps,
	}

	// 1. Set Headers for Streaming
	c.Set("Content-Type", "text/html; charset=utf-8")
	c.Set("Transfer-Encoding", "chunked")
	c.Set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate")
	c.Set("Pragma", "no-cache")
	c.Set("Expires", "0")
	c.Set("X-Accel-Buffering", "no")

	c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		flush := func() {
			w.Flush()
		}

		ctx := context.Background()

		// Prepare Header Props for Initial Render
		displayNameHTML := h.createDisplayChars(name, day)
		var klakiniChars []string
		for _, dc := range displayNameHTML {
			if dc.IsBad {
				klakiniChars = append(klakiniChars, dc.Char)
			}
		}

		initialProps := analysis.SimilarNamesProps{
			IsLoading:             true,
			IsAuspicious:          isAuspicious,
			DisableKlakini:        disableKlakiniTable,
			DisplayNameHTML:       displayNameHTML, // Needed for header name display
			HeaderDisplayNameHTML: h.createHeaderDisplayChars(name, day),
			KlakiniChars:          klakiniChars,
			CleanedName:           name,
			InputDay:              service.GetThaiDay(day),
			IsVIP:                 isVIP,
		}

		// A. Create the lazy Results component that renders the SKELETON SHELL initially
		lazyResults := templ.ComponentFunc(func(ctx context.Context, w2 io.Writer) error {
			// This renders the Header + Top4Skeleton + TableSkeleton
			if err := analysis.SimilarNamesTable(initialProps).Render(ctx, w2); err != nil {
				return err
			}

			// Flush the Shell
			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				w.Flush()
			}

			// --- HEAVY LIFTING STARTS HERE (Progressive) ---

			// --- PHASE 1: Top 4 (Fast-ish if indexed) ---
			normalizedInput := strings.TrimSpace(name)
			allowKlakiniTop4 := !disableKlakiniTop4
			log.Printf("⏱️  [PERF] Starting GetBestSimilarNames (fetch 100, show top 4)")
			startBest := time.Now()
			// Fetch 100 names for proper ranking calculation
			bestCandidates, errBest := h.namesMiracleRepo.GetBestSimilarNames(name, day, 100, allowKlakiniTop4)
			log.Printf("✅ [PERF] GetBestSimilarNames completed in: %v (found %d names)", time.Since(startBest), len(bestCandidates))

			var top4, last4, fullBestList []domain.SimilarNameResult
			var totalCountBest int

			// If we got Best Names independently, render them now!
			if errBest == nil && len(bestCandidates) > 0 {
				h.calculateScoresAndHighlights(bestCandidates, day)
				// Get all ranked names first
				t4, l4, fl, totalCount := h.getBestNames(bestCandidates, 100, allowKlakiniTop4)
				totalCountBest = totalCount
				top4 = t4
				last4 = l4
				fullBestList = fl

				top4Props := analysis.SimilarNamesProps{
					Top4Names:          top4,
					Last4Names:         last4,
					TotalFilteredCount: totalCountBest,
					ShowTop4:           isVIP, // Default view for VIP members is Top 4
					DisplayNameHTML:    displayNameHTML,
					DisableKlakiniTop4: disableKlakiniTop4,
					IsVIP:              isVIP,
					CleanedName:        name, // Essential for links
					InputDay:           service.GetThaiDay(day),
				}

				// Swap the Top 4 Skeleton with Real Content
				// Target ID: "top4-section"
				err := analysis.SwapContent("top4-section", analysis.Top4Section(top4Props)).Render(ctx, w2)
				if err != nil {
					log.Printf("Error swap top4: %v", err)
				}
				if f, ok := w2.(http.Flusher); ok {
					f.Flush()
				} else {
					w.Flush()
				}
			}

			// --- PHASE 2: Table (Slow - Full Scan) ---
			limit := 100
			if isVIP || isAdmin {
				limit = 1000
			}
			similarNames, err := h.fetchSimilarNames(name, day, false, repoAllowKlakini, limit, nil)
			if err != nil {
				log.Printf("ERROR: fetchSimilarNames failed: %v", err)
				return nil
			}

			// Normalization
			for i := range similarNames {
				normalizedDbName := strings.TrimSpace(similarNames[i].ThName)
				if normalizedDbName != normalizedInput && similarNames[i].Similarity > 0.99 {
					similarNames[i].Similarity = 0.99
				}
			}

			// If Top4 failed earlier (Fallback), calculate it now using full list
			if errBest != nil || len(bestCandidates) == 0 {
				bestCandidates = make([]domain.SimilarNameResult, len(similarNames))
				copy(bestCandidates, similarNames)
				/*
					for _, n := range similarNames {
						if !n.HasBadPair {
							if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
								continue
							}
							bestCandidates = append(bestCandidates, n)
						}
					}
				*/
				h.calculateScoresAndHighlights(bestCandidates, day) // Ensure scores
				top4, last4, fullBestList, totalCountBest = h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

				// RENDER TOP 4 (Late Update)
				top4Props := analysis.SimilarNamesProps{
					Top4Names:          top4,
					Last4Names:         last4,
					TotalFilteredCount: totalCountBest,
					ShowTop4:           isVIP,
					DisplayNameHTML:    displayNameHTML,
					DisableKlakiniTop4: disableKlakiniTop4,
					IsVIP:              isVIP,
					CleanedName:        name,
					InputDay:           service.GetThaiDay(day),
				}
				err := analysis.SwapContent("top4-section", analysis.Top4Section(top4Props)).Render(ctx, w2)
				if err != nil {
					log.Printf("Error swap top4 fallback: %v", err)
				}
				if f, ok := w2.(http.Flusher); ok {
					f.Flush()
				} else {
					w.Flush()
				}
			} else {
				// We still need to calculate scores for the Table view mostly
				h.calculateScoresAndHighlights(similarNames, day)
			}

			// 3. Filter for TABLE
			tableCandidates := similarNames
			if len(fullBestList) > 0 {
				tableCandidates = fullBestList
			}
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

			tableProps := analysis.SimilarNamesProps{
				SimilarNames:    tableCandidates,
				IsAuspicious:    isAuspicious,
				DisableKlakini:  disableKlakiniTable,
				DisplayNameHTML: displayNameHTML,
				KlakiniChars:    klakiniChars,
				IsVIP:           isVIP,
			}

			// C. Render the Table and Swap Script
			// Target ID: "similar-names-list-section"
			if err := analysis.SwapContent("similar-names-list-section", analysis.SimilarNamesList(tableProps)).Render(ctx, w2); err != nil {
				return err
			}

			// Also need to initialize JS events if needed? SwapContent does simplistic handling.
			// SimilarNamesList has Toggles that use HTMX. HTMX needs reprocessing.
			// SwapContent includes logic if we added it.

			if f, ok := w2.(http.Flusher); ok {
				f.Flush()
			} else {
				w.Flush()
			}
			return nil
		})

		indexProps.Results = lazyResults

		// Render Index (Page Shell)
		// This prints <html>...<body>...<ResultsPlaceholder>...
		if err := analysis.Index(indexProps).Render(ctx, w); err != nil {
			log.Printf("Error rendering index: %v", err)
		}

		flush()
	})

	return nil
}

// AnalyzeLinguistically analyzes the name using the linguistic service and renders the result.
func (h *NumerologyHandler) AnalyzeLinguistically(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	if name == "" {
		return c.Status(fiber.StatusBadRequest).SendString("Name parameter is required.")
	}

	// 1. Try Cache
	var cachedMarkdown string
	err := h.db.QueryRow("SELECT analysis_markdown FROM linguistic_cache WHERE name_text = $1", name).Scan(&cachedMarkdown)
	if err == nil && cachedMarkdown != "" {
		log.Printf("DEBUG: Linguistic Cache HIT for '%s'", name)
		return templ_render.Render(c, analysis.LinguisticModal(name, cachedMarkdown))
	}

	// 2. AI Call
	analysisRes, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		log.Printf("Error from linguistic service: %v", err)
		return c.Status(fiber.StatusInternalServerError).SendString(fmt.Sprintf("Service Error: %v", err))
	}

	// 3. Save to Cache (Background or Sync - let's do sync for simplicity and reliability)
	_, _ = h.db.Exec("INSERT INTO linguistic_cache (name_text, analysis_markdown) VALUES ($1, $2) ON CONFLICT (name_text) DO NOTHING", name, analysisRes)

	return templ_render.Render(c, analysis.LinguisticModal(name, analysisRes))
}

func (h *NumerologyHandler) GetBadNumbersAPI(c *fiber.Ctx) error {
	meanings, err := h.numberPairCache.GetAllMeanings()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to load meanings"})
	}

	uniqueBad := make(map[int]bool)
	for _, m := range meanings {
		if service.IsBadPairType(m.PairType) {
			if val, err := strconv.Atoi(m.PairNumber); err == nil {
				uniqueBad[val] = true
			}
		}
	}

	badNumbers := []int{}
	for k := range uniqueBad {
		badNumbers = append(badNumbers, k)
	}
	sort.Ints(badNumbers)

	return c.JSON(fiber.Map{
		"bad_numbers": badNumbers,
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

	return templ_render.Render(c, analysis.NumberMeaningsModal(meanings))
}

// AnalyzeLinguisticallyAPI returns JSON for mobile apps
func (h *NumerologyHandler) AnalyzeLinguisticallyAPI(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	if name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Name is required"})
	}

	// Try Cache
	var cachedMarkdown string
	err := h.db.QueryRow("SELECT analysis_markdown FROM linguistic_cache WHERE name_text = $1", name).Scan(&cachedMarkdown)
	if err == nil && cachedMarkdown != "" {
		return c.JSON(fiber.Map{
			"name":     name,
			"analysis": cachedMarkdown,
			"source":   "cache",
		})
	}

	analysisRes, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": fmt.Sprintf("Analysis failed: %v", err)})
	}

	// Save
	_, _ = h.db.Exec("INSERT INTO linguistic_cache (name_text, analysis_markdown) VALUES ($1, $2) ON CONFLICT (name_text) DO NOTHING", name, analysisRes)

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
			// No bad pairs found - this is a premium name
			return true
		}

		satP := isPillarStrictPremium(names[i].SatNum)
		shaP := isPillarStrictPremium(names[i].ShaNum)
		names[i].IsTopTier = satP && shaP
		if names[i].IsTopTier {
			// fmt.Printf("DEBUG: PREMIUM FOUND: %s\n", names[i].ThName)
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

		// Calculate Category counts - Initialize all categories with 0
		counts := map[string]int{
			"การงาน":  0,
			"การเงิน": 0,
			"ความรัก": 0,
			"สุขภาพ":  0,
		}

		for _, p := range names[i].SatNum {
			if cats, ok := h.numberCategoryCache.GetCategories(p); ok {
				for _, c := range cats {
					counts[c]++
				}
			}
		}
		for _, p := range names[i].ShaNum {
			if cats, ok := h.numberCategoryCache.GetCategories(p); ok {
				for _, c := range cats {
					counts[c]++
				}
			}
		}
		names[i].CategoryCounts = counts

		names[i].TSat = make([]domain.PairTypeInfo, len(satMeanings))
		for j, meaning := range satMeanings {
			color := meaning.Meaning.Color
			// Force RED for bad pairs to fix "sad brown" color issue
			if service.IsBadPairType(meaning.Meaning.PairType) {
				color = "#D32F2F"
			}
			names[i].TSat[j] = domain.PairTypeInfo{Type: meaning.Meaning.PairType, Color: color}
		}
		names[i].TSha = make([]domain.PairTypeInfo, len(shaMeanings))
		for j, meaning := range shaMeanings {
			color := meaning.Meaning.Color
			// Force RED for bad pairs to fix "sad brown" color issue
			if service.IsBadPairType(meaning.Meaning.PairType) {
				color = "#D32F2F"
			}
			names[i].TSha[j] = domain.PairTypeInfo{Type: meaning.Meaning.PairType, Color: color}
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

func (h *NumerologyHandler) findAuspiciousNames(name, day string, repoAllowKlakini, findGoodOnly bool, limit int, onProgress func(int, int)) ([]domain.SimilarNameResult, error) {
	// User's logic at backend is strictly similarity-based (Levenshtein-like)
	// without caring about vowels or consonants.
	preferredConsonant := ""

	// Single efficient DB call. Database filters by similarity, Klakini, and Good Only rules.
	// This ensures we scan the entire table in the most optimal way.
	auspiciousNames, err := h.namesMiracleRepo.GetAuspiciousNames(name, preferredConsonant, day, limit, 0, repoAllowKlakini, findGoodOnly)
	if err != nil {
		return nil, fmt.Errorf("error fetching auspicious names: %w", err)
	}

	// Calculate scores for display
	h.calculateScoresAndHighlights(auspiciousNames, day)

	// Report 100% progress
	if onProgress != nil {
		onProgress(len(auspiciousNames), 100)
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
	limit := 100
	if c.Locals("IsVIP") == true {
		limit = 1000
	}
	// Always fetch from the general fetcher to get a pool for both cards and table
	similarNames, err = h.fetchSimilarNames(name, day, false, repoAllowKlakini, limit, nil)

	if err != nil {
		log.Printf("Error getting names: %v", err)
		return c.SendString("<div>Error loading names.</div>")
	}

	// Cap similarity at 99% if not exact match (Fix for "100%" confusion on similar phonetics)
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
		bestCandidates = make([]domain.SimilarNameResult, len(similarNames))
		copy(bestCandidates, similarNames)
	}

	top4, last4, fullList, totalCountBest := h.getBestNames(bestCandidates, 100, allowKlakiniTop4)
	if errBest == nil && len(fullList) > 0 {
		tableCandidates = fullList
	}

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

	// Default to VIP view for VIP members if not explicitly toggled
	if c.Query("show_top4") == "" && isVIP {
		showTop4 = true
	}

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
		day = "thursday"
	}

	isVIP := c.Locals("IsVIP") == true

	// Calculate Solar System Props (Fast)
	solarProps, _ := h.getSolarSystemProps(name, day, !disableKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakini

	// Render SolarSystem AND trigger OOB refresh for bottom content
	return templ_render.Render(c, analysis.SolarSystemAndRefresh(solarProps, name, day))
}

func (h *NumerologyHandler) getBestNames(candidates []domain.SimilarNameResult, limit int, allowKlakini bool) ([]domain.SimilarNameResult, []domain.SimilarNameResult, []domain.SimilarNameResult, int) {
	var top10 []domain.SimilarNameResult
	var last10 []domain.SimilarNameResult

	// 1. Filter for "Strict Best" (IsTopTier - All Green)
	var bestNames []domain.SimilarNameResult
	// 2. Also track "Standard Good" (No Bad Pairs) as backup
	var standardGoodNames []domain.SimilarNameResult

	for _, c := range candidates {
		// Basic requirement: No Bad Pairs
		// Klakini requirement depends on allowKlakini
		if !c.HasBadPair {
			if !allowKlakini && len(c.KlakiniChars) > 0 {
				continue
			}

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

	// FALLBACK: If we have very few results (e.g. < 10 for Top 10), just take whatever we have from candidates
	// This ensures on Localhost/Dev or with bad data we still see SOMETHING.
	if len(finalList) < 10 {
		// Find candidates not yet in finalList
		seen := make(map[int]bool)
		for _, f := range finalList {
			seen[f.NameID] = true
		}

		var fallback []domain.SimilarNameResult
		for _, c := range candidates {
			if !seen[c.NameID] {
				// Try to filter Klakini first if requested
				if !allowKlakini && len(c.KlakiniChars) > 0 {
					continue
				}
				fallback = append(fallback, c)
			}
		}

		// If still need more and strict klakini was on, retry without strict klakini check (absolute desperation)
		if len(finalList)+len(fallback) < 10 && !allowKlakini {
			for _, c := range candidates {
				if !seen[c.NameID] {
					// Check if already in fallback (inefficient but safe for small list)
					alreadyInFallback := false
					for _, fb := range fallback {
						if fb.NameID == c.NameID {
							alreadyInFallback = true
							break
						}
					}
					if !alreadyInFallback {
						fallback = append(fallback, c)
					}
				}
			}
		}

		// Fill up to 10 or limit
		needed := limit - len(finalList)
		if needed > 0 {
			if len(fallback) < needed {
				needed = len(fallback)
			}
			finalList = append(finalList, fallback[:needed]...)
		}
	}

	// 4. Limit to requested size
	if len(finalList) > limit {
		finalList = finalList[:limit]
	}

	// 5. Derive Top 10 and Last 10 (ranks #91-#100)
	if len(finalList) > 0 {
		// Get Top 10
		if len(finalList) >= 10 {
			top10 = finalList[:10]
		} else {
			top10 = finalList
		}

		// Get Last 10 from the end of this ranked set (ranks #91-#100 if 100 results)
		if len(finalList) >= 10 {
			last10 = finalList[len(finalList)-10:]
		} else {
			last10 = finalList
		}
	}

	return top10, last10, finalList, len(finalList)
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

func (h *NumerologyHandler) fetchSimilarNames(name, day string, isAuspicious, repoAllowKlakini bool, limit int, onProgress func(int, int)) ([]domain.SimilarNameResult, error) {
	return h.fetchSimilarNamesEnhanced(name, day, isAuspicious, repoAllowKlakini, isAuspicious, limit, onProgress)
}

func (h *NumerologyHandler) fetchSimilarNamesEnhanced(name, day string, isAuspicious, repoAllowKlakini, findGoodOnly bool, limit int, onProgress func(int, int)) ([]domain.SimilarNameResult, error) {
	// All similarity search modes now use the unified SQL-based search logic.
	// This ensures consistency, performance, and strict adherence to the requested limit.
	return h.findAuspiciousNames(name, day, repoAllowKlakini, findGoodOnly, limit, onProgress)
}

func getMeaningsAndScores(pairs []string, pairCache *cache.NumberPairCache) ([]domain.PairMeaningResult, int, int) {
	var meanings []domain.PairMeaningResult
	var posScore, negScore int
	for _, p := range pairs {
		if meaning, ok := pairCache.GetMeaning(p); ok {
			// Force RED color for bad pairs to fix "sad brown" display issue globally
			if service.IsBadPairType(meaning.PairType) {
				meaning.Color = "#D32F2F"
				meaning.IsBad = true
			}
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

	// Calculate Category counts - Initialize all categories with 0
	counts := map[string]int{
		"การงาน":  0,
		"การเงิน": 0,
		"ความรัก": 0,
		"สุขภาพ":  0,
	}

	// Calculate Category breakdown (Good vs Bad)
	breakdown := make(map[string]domain.CategoryBreakdown)
	for cat := range counts {
		color := "#A0A0A0"
		switch cat {
		case "การงาน":
			color = "#90CAF9"
		case "การเงิน":
			color = "#FFCC80"
		case "ความรัก":
			color = "#F48FB1"
		case "สุขภาพ":
			color = "#80CBC4"
		}
		breakdown[cat] = domain.CategoryBreakdown{Good: 0, Bad: 0, Color: color}
	}

	// Helper function to update breakdown
	allowedCategories := map[string]bool{
		"การงาน":  true,
		"การเงิน": true,
		"ความรัก": true,
		"สุขภาพ":  true,
	}

	// Helper map to aggregate unique keywords per category
	categoryKeywords := make(map[string]map[string]bool)
	categoryBadKeywords := make(map[string]map[string]bool)
	for cat := range counts {
		categoryKeywords[cat] = make(map[string]bool)
		categoryBadKeywords[cat] = make(map[string]bool)
	}

	updateBreakdown := func(pairNumber string) {
		// Get categories directly from cache
		if cats, ok := h.numberCategoryCache.GetCategories(pairNumber); ok {
			keywords := h.numberCategoryCache.GetKeywords(pairNumber)

			// Determine Good/Bad status from the SOURCE of Truth (PairCache - same as score)
			isGood := false
			isBad := false
			if m, ok := h.numberPairCache.GetMeaning(pairNumber); ok {
				if service.IsGoodPairType(m.PairType) {
					isGood = true
				} else if service.IsBadPairType(m.PairType) {
					isBad = true
				}
			} else {
				// Fallback to category cache if pair meaning missing (unlikely)
				numberType := h.numberCategoryCache.GetNumberType(pairNumber)
				isGood = (numberType == "ดี")
				isBad = (numberType == "ร้าย")
			}

			for _, c := range cats {
				if !allowedCategories[c] {
					continue
				}

				counts[c]++ // Update count

				current := breakdown[c]
				if isGood {
					current.Good++
				} else if isBad {
					current.Bad++
				}

				// Aggregate keywords based on good/bad status
				for _, kw := range keywords {
					if kw != "" {
						if isGood {
							categoryKeywords[c][kw] = true
						} else if isBad {
							categoryBadKeywords[c][kw] = true
						}
					}
				}

				breakdown[c] = current
			}
		}
	}

	// Process numerology pairs
	for _, pairNumber := range numerologyPairs {
		updateBreakdown(pairNumber)
	}

	// Process shadow pairs
	for _, pairNumber := range shadowPairs {
		updateBreakdown(pairNumber)
	}

	// Consolidate keywords into breakdown struct
	for cat, kwMap := range categoryKeywords {
		if entry, exists := breakdown[cat]; exists {
			var kws []string
			for kw := range kwMap {
				kws = append(kws, kw)
			}
			sort.Strings(kws)
			entry.Keywords = kws

			// Add bad keywords
			var badKws []string
			for kw := range categoryBadKeywords[cat] {
				badKws = append(badKws, kw)
			}
			sort.Strings(badKws)
			entry.BadKeywords = badKws

			// FIX: Combine Good + Bad keywords into main 'Keywords' field
			// so that Mobile App (which reads only 'keywords') displays them.
			// The Mobile App handles coloring based on 'HasBad' flag.
			combinedKws := make([]string, 0, len(kws)+len(badKws))
			combinedKws = append(combinedKws, kws...)
			combinedKws = append(combinedKws, badKws...)
			entry.Keywords = combinedKws

			breakdown[cat] = entry
		}
	}

	// Calculate Total Score % (Base Category Percentage logic)
	totalBasePercent := 0.0
	for _, cat := range []string{"สุขภาพ", "การงาน", "การเงิน", "ความรัก"} {
		if bd, ok := breakdown[cat]; ok && bd.Good > 0 {
			totalBasePercent += 25.0
		}
	}

	// Prepare Display Summaries (Backend Logic for UI)
	var analysisSummaries []domain.AnalysisSummary

	toDisplayKeywords := func(mixedKws []string, badKws []string) []domain.DisplayKeyword {
		var content []domain.DisplayKeyword

		// Create set of bad keywords for exclusion from mixed list (which contains both good+bad)
		badSet := make(map[string]bool)
		for _, k := range badKws {
			badSet[k] = true
		}

		// Add Good keywords (filter out bads from the mixed list)
		for _, k := range mixedKws {
			if !badSet[k] {
				content = append(content, domain.DisplayKeyword{Text: k, IsBad: false})
			}
		}
		// Add Bad keywords
		for _, k := range badKws {
			content = append(content, domain.DisplayKeyword{Text: k, IsBad: true})
		}
		return content
	}

	// Unified Logic: Show all relevant categories separately matching Pie Chart colors
	order := []string{"สุขภาพ", "การงาน", "การเงิน", "ความรัก"}
	for _, cat := range order {
		bd := breakdown[cat]
		content := toDisplayKeywords(bd.Keywords, bd.BadKeywords)

		// Show as long as there is content (Good OR Bad)
		if len(content) > 0 {
			title := cat
			isBad := false
			// Check if there are bad keywords in this category
			if len(bd.BadKeywords) > 0 {
				isBad = true
			}

			analysisSummaries = append(analysisSummaries, domain.AnalysisSummary{
				Title:       title,
				Content:     content,
				CategoryKey: cat,
				IsBad:       isBad,
			})
		}
	}

	// Determine Header Title & Color
	resultTitle := ""
	resultColor := ""
	resultStyle := "default"

	if grandTotalScore >= 0 {
		resultTitle = "ชื่อนี้ดี"
		resultColor = "#10B981" // Emerald Green
		resultStyle = "emerald"
	} else {
		if numPos+shaPos == 0 {
			resultTitle = "ชื่อนี้ส่งผลร้าย"
			resultColor = "#EF4444"
		} else {
			resultTitle = "ชื่อนี้ร้ายมากกว่าดี"
			resultColor = "#EF4444"
		}
	}

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
		TotalPercent:         totalBasePercent,
		TotalPairs:           len(numMeanings) + len(shaMeanings),
		IsSunDead:            grandTotalScore < 0,
		AllUniquePairs:       allUniquePairs,
		DecodedParts:         results,
		TotalNumerologyValue: totalNumerologyValue,
		TotalShadowValue:     totalShadowValue,
		IsVIP:                isVIP,
		CategoryCounts:       counts,
		CategoryBreakdown:    breakdown,
		AnalysisSummaries:    analysisSummaries,
		ResultTitle:          resultTitle,
		ResultColor:          resultColor,
		ResultStyle:          resultStyle,
	}, nil
}

// AnalyzeAPIStreaming handles streaming response for the mobile app
func (h *NumerologyHandler) AnalyzeAPIStreaming(c *fiber.Ctx) error {
	c.Set("Content-Type", "text/event-stream")
	c.Set("Cache-Control", "no-cache")
	c.Set("Connection", "keep-alive")
	c.Set("Transfer-Encoding", "chunked")
	c.Set("X-Accel-Buffering", "no")      // Disable Nginx buffering
	c.Set("Content-Encoding", "identity") // Explicitly disable compression
	c.Set("X-No-Compression", "yes")      // Hint for proxies

	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if day == "" {
		day = strings.ToLower(strings.TrimSpace(c.Query("birth_day")))
	}
	if day == "" {
		day = "thursday"
	}
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on" || c.Query("auspicious") == "1" ||
		c.Query("is_auspicious") == "true" || c.Query("is_auspicious") == "on" || c.Query("is_auspicious") == "1"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on" || c.Query("disable_klakini") == "1"

	// VIP/Admin Detection (Handled by optionalAuthMiddleware)
	isVIP := c.Locals("IsVIP") == true
	isAdmin := c.Locals("IsAdmin") == true

	log.Printf("DEBUG STREAM: Name=%s, Day=%s, Vip=%v, Admin=%v", name, day, isVIP, isAdmin)

	// Parse all params BEFORE entering the stream closure (Ctx is not concurrency safe)
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on" || c.Query("disable_klakini_top4") == "1"
	section := c.Query("section")

	limit := 3
	if isVIP || isAdmin {
		limit = 1000 // Support full list for VIPs
	}

	// If client requested a limit, respect it but CAP it by VIP status
	if qLimit := c.Query("limit"); qLimit != "" {
		if val, err := strconv.Atoi(qLimit); err == nil && val > 0 {
			if !isVIP && !isAdmin && val > 3 {
				val = 3 // Enforce cap
			}
			if val > 1000 {
				val = 1000 // Absolute cap
			}
			limit = val
		}
	}

	disableKlakiniTable := disableKlakini
	repoAllowKlakini := !disableKlakiniTable // Main search should respect table toggle for accurate progress reporting

	log.Printf("DEBUG STREAM: Name=%s, Day=%s, Vip=%v, Admin=%v, KlakiniOff=%v, Limit=%d", name, day, isVIP, isAdmin, disableKlakini, limit)

	// Stream Body
	c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		flush := func() {
			w.Flush()
		}

		// Non-compressible Padding to bypass Gzip/Nginx buffering
		// 5KB of varied data
		paddingBuilder := strings.Builder{}
		for i := 0; i < 1500; i++ {
			paddingBuilder.WriteString("0123456789abcdefghijklmnopqrstuvwxyz")
		}
		fmt.Fprintf(w, ": %s\n\n", paddingBuilder.String())
		flush()

		onProgress := func(found, scanned int) {
			// Write progress event
			fmt.Fprintf(w, "data: {\"type\": \"progress\", \"count\": %d, \"total\": %d}\n\n", found, scanned)
			flush()
		}

		// Send initial progress immediately to stop "stuck" feel
		onProgress(0, 50)
		flush()

		// Params moved outside closure

		// Call fetchSimilarNames with Progress Callback
		similarNames, err := h.fetchSimilarNames(name, day, isAuspicious, repoAllowKlakini, limit, onProgress)

		log.Printf("DEBUG STREAM: fetchSimilarNames returned %d items, err=%v", len(similarNames), err)

		if err != nil {
			log.Printf("Streaming Error: fetchSimilarNames failed for %s: %v", name, err)
			fmt.Fprintf(w, "data: {\"type\": \"error\", \"message\": \"Analysis failed: %v\"}\n\n", err)
			flush()
			return
		}

		// Ensure slice is never nil for JSON
		if similarNames == nil {
			similarNames = []domain.SimilarNameResult{}
		}

		displayNameHTML := h.createDisplayChars(name, day)
		var klakiniChars []string
		for _, dc := range displayNameHTML {
			if dc.IsBad {
				klakiniChars = append(klakiniChars, dc.Char)
			}
		}

		if err == nil {
			normalizedInput := strings.TrimSpace(name)
			for i := range similarNames {
				normalizedDbName := strings.TrimSpace(similarNames[i].ThName)
				if normalizedDbName != normalizedInput && similarNames[i].Similarity > 0.99 {
					similarNames[i].Similarity = 0.99
				}
			}
			// Redundant: calculateScoresAndHighlights is now called inside findAuspiciousNames or similar logic
			// and handles consistency. We skip it here if already calculated.
			if len(similarNames) > 0 && similarNames[0].DisplayNameHTML == nil {
				h.calculateScoresAndHighlights(similarNames, day)
			}
		}
		log.Printf("DEBUG STREAM: After check similarNames count = %d", len(similarNames))

		// --- Process Results (Logic from AnalyzeAPI) ---

		// 1. Table Candidates
		tableCandidates := similarNames
		if disableKlakiniTable {
			tableCandidates = h.filterKlakiniNames(similarNames)
		}
		if len(tableCandidates) > limit {
			tableCandidates = tableCandidates[:limit]
		}
		if tableCandidates == nil {
			tableCandidates = []domain.SimilarNameResult{}
		}

		// 2. Derive Top 4 and Last 4
		// Formatting
		formatSimple := func(names []domain.SimilarNameResult, startRank int) []fiber.Map {
			var result []fiber.Map
			for i, n := range names {
				result = append(result, fiber.Map{
					"th_name":           n.ThName,
					"rank":              startRank + i,
					"display_name_html": n.DisplayNameHTML,
					"total_score":       n.TotalScore,
					"similarity":        n.Similarity,
					"is_top_tier":       n.IsTopTier,
					"has_bad_pair":      n.HasBadPair,
					"sat_num":           n.SatNum,
					"sha_num":           n.ShaNum,
					"t_sat":             n.TSat,
					"t_sha":             n.TSha,
				})
			}
			return result
		}

		var top4, last4 []domain.SimilarNameResult
		var bestNamesTop4, bestNamesRecommended []fiber.Map

		// For Best Names (Top 4 / Ranking), use the results from our deep search if in Auspicious mode.
		// This ensures consistency between the ranking cards and the table.
		var bestCandidates []domain.SimilarNameResult
		allowKlakiniTop4 := !disableKlakiniTop4

		if isAuspicious && len(similarNames) > 0 {
			// Reuse results from the deep global search
			bestCandidates = similarNames
		} else {
			// Normal mode: Fetch specifically for "Best" section using quality-based filtering in SQL
			var errBest error
			bestCandidates, errBest = h.namesMiracleRepo.GetBestSimilarNames(name, day, limit, allowKlakiniTop4)
			if errBest == nil && len(bestCandidates) > 0 {
				h.calculateScoresAndHighlights(bestCandidates, day)
			} else {
				// Final backup: try to salvage from similarNames even in normal mode
				bestCandidates = []domain.SimilarNameResult{}
				for _, n := range similarNames {
					if !n.HasBadPair {
						if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
							continue
						}
						bestCandidates = append(bestCandidates, n)
					}
				}
			}
		}

		top4, last4, _, _ = h.getBestNames(bestCandidates, limit, allowKlakiniTop4)

		if top4 == nil {
			top4 = []domain.SimilarNameResult{}
		}
		if last4 == nil {
			last4 = []domain.SimilarNameResult{}
		}

		// Rankings for similar_names
		finalSimilarNames := tableCandidates
		if len(finalSimilarNames) > limit {
			finalSimilarNames = finalSimilarNames[:limit]
		}

		formattedSimilarNames := formatSimple(finalSimilarNames, 1)

		bestNamesTop4 = formatSimple(top4, 1)
		bestNamesRecommended = formatSimple(last4, 5) // Simple sequential for recommended

		totalDisplayCount := len(tableCandidates) // This is what the user expects to see
		log.Printf("DEBUG STREAM FINAL: simCount=%d, tableCount=%d, limit=%d", len(similarNames), len(tableCandidates), limit)

		// 3. Solar System Props (if needed)
		// Section resolved outside
		var solarProps interface{}
		if section == "" || section == "solar" {
			props, _ := h.getSolarSystemProps(name, day, !disableKlakini, isVIP)
			solarProps = props
		}

		log.Printf("DEBUG STREAM: FINAL SEND: formatted count = %d, total count = %d", len(formattedSimilarNames), totalDisplayCount)

		// Response Map
		resp := fiber.Map{
			"th_name":              name,
			"display_name_html":    displayNameHTML,
			"klakini_chars":        klakiniChars,
			"similar_names":        formattedSimilarNames,
			"total_similar_count":  len(similarNames),
			"is_vip":               isVIP,
			"is_admin":             isAdmin,
			"total_filtered_count": totalDisplayCount,
			"best_names": fiber.Map{
				"target_name_html":         displayNameHTML,
				"total_count":              totalDisplayCount,
				"top_4":                    bestNamesTop4,
				"recommended":              bestNamesRecommended,
				"title_prefix_top4":        "อันดับชื่อที่เป็นมงคลที่สุด",
				"title_prefix_recommended": "ชื่อแนะนำอื่นๆ ที่เป็นมงคล",
			},
		}

		if section == "" {
			resp["solar_system"] = solarProps
		}

		// Send FINAL RESULT safely
		jsonBytes, errJson := json.Marshal(resp)
		if errJson != nil {
			log.Printf("Streaming Marshal Error: %v", errJson)
			fmt.Fprintf(w, "data: {\"type\": \"error\", \"message\": \"Failed to marshal response\"}\n\n")
		} else {
			// Write safely without embedding in split format
			fmt.Fprintf(w, "data: {\"type\": \"result\", \"payload\": ")
			w.Write(jsonBytes)
			fmt.Fprintf(w, "}\n\n")
		}
		flush()
	})

	return nil
}

func (h *NumerologyHandler) DebugRepo(c *fiber.Ctx) error {
	res, err := h.namesMiracleRepo.GetSimilarNames("หมวย", "monday", 10, 0, true)
	if err != nil {
		return c.JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"count": len(res), "data": res})
}
