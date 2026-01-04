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
	numerologyCache     *cache.NumerologyCache
	shadowCache         *cache.NumerologyCache
	klakiniCache        *cache.KlakiniCache
	numberPairCache     *cache.NumberPairCache
	numberCategoryCache *cache.NumberCategoryCache
	namesMiracleRepo    ports.NamesMiracleRepository
	linguisticService   *service.LinguisticService
	sampleNamesCache    *cache.SampleNamesCache
	phoneNumberService  *service.PhoneNumberService
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

	// Calculate Total Score % (Base Category Percentage logic)
	// Web Logic: (TotalGood - TotalBad) / TotalPairs * 100 ??
	// Actually current web logic uses "GetBaseCategoryPercentage" which is:
	// length(ActiveCategories) * 25.0
	// Active Category = Has > 0 Good numbers.

	totalBasePercent := 0.0
	for _, cat := range []string{"สุขภาพ", "การงาน", "การเงิน", "ความรัก"} {
		if bd, ok := breakdown[cat]; ok && bd.Good > 0 {
			totalBasePercent += 25.0
		}
	}

	return c.JSON(fiber.Map{
		"number":             number,
		"main_pairs":         mainPairs,
		"hidden_pairs":       hiddenPairs,
		"sum_meaning":        sumMeaning,
		"category_breakdown": breakdown,
		"total_percent":      totalBasePercent,
	})
}

func (h *NumerologyHandler) AnalyzeAPI(c *fiber.Ctx) error {
	name := service.SanitizeInput(c.Query("name"))
	day := strings.ToLower(strings.TrimSpace(c.Query("day")))
	if day == "" {
		day = "thursday"
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

	if section == "" || section == "names" {
		disableKlakiniTable := disableKlakini
		disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on" || c.Query("disable_klakini_top4") == "1"
		repoAllowKlakini := !disableKlakiniTable || !disableKlakiniTop4

		similarNames, err := h.fetchSimilarNames(name, day, isAuspicious, repoAllowKlakini)
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
				if !n.HasBadPair {
					if !allowKlakiniTop4 && len(n.KlakiniChars) > 0 {
						continue
					}
					bestCandidates = append(bestCandidates, n)
				}
			}
		}

		top4, last4, totalBest = h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

		// 3. Apply Limit based on VIP/Admin status
		finalSimilarNames = tableCandidates
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
	isAuspicious := c.Query("auspicious") == "true" || c.Query("auspicious") == "on"
	disableKlakini := c.Query("disable_klakini") == "true" || c.Query("disable_klakini") == "on"
	disableKlakiniTable := disableKlakini
	disableKlakiniTop4 := c.Query("disable_klakini_top4") == "true" || c.Query("disable_klakini_top4") == "on"
	repoAllowKlakini := !disableKlakiniTable || !disableKlakiniTop4

	isVIP := c.Locals("IsVIP") == true

	// Calculate Solar System Props (Fast - mostly cache)
	solarProps, _ := h.getSolarSystemProps(name, day, repoAllowKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakiniTable
	solarProps.SkipTrigger = true

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
			bestCandidates, errBest := h.namesMiracleRepo.GetBestSimilarNames(name, day, 100, allowKlakiniTop4)

			var top4, last4 []domain.SimilarNameResult
			var totalCountBest int

			// If we got Best Names independently, render them now!
			if errBest == nil && len(bestCandidates) > 0 {
				h.calculateScoresAndHighlights(bestCandidates, day)
				top4, last4, totalCountBest = h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

				top4Props := analysis.SimilarNamesProps{
					Top4Names:          top4,
					Last4Names:         last4,
					TotalFilteredCount: totalCountBest,
					ShowTop4:           false, // Default view
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
			similarNames, err := h.fetchSimilarNames(name, day, false, repoAllowKlakini)
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
				top4, last4, totalCountBest = h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

				// RENDER TOP 4 (Late Update)
				top4Props := analysis.SimilarNamesProps{
					Top4Names:          top4,
					Last4Names:         last4,
					TotalFilteredCount: totalCountBest,
					ShowTop4:           false,
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

	analysisRes, err := h.linguisticService.AnalyzeName(name)
	if err != nil {
		log.Printf("Error from linguistic service: %v", err)
		// Return actual error for debugging
		return c.Status(fiber.StatusInternalServerError).SendString(fmt.Sprintf("Service Error: %v", err))
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
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": fmt.Sprintf("Analysis failed: %v", err)})
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
						// fmt.Printf("DEBUG: %s Pair %s Type '%s' NOT Good\n", names[i].ThName, p, m.PairType)
						return false // Found non-Good pair (Neutral or Bad)
					}
				} else {
					// fmt.Printf("DEBUG: %s Pair %s Unknown/Not Found in Cache\n", names[i].ThName, p)
					return false // Unknown pair is not Good
				}
			}
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

	top4, last4, totalCountBest := h.getBestNames(bestCandidates, 100, allowKlakiniTop4)

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
		day = "thursday"
	}

	isVIP := c.Locals("IsVIP") == true

	// Calculate Solar System Props (Fast)
	solarProps, _ := h.getSolarSystemProps(name, day, !disableKlakini, isVIP)
	solarProps.DisableKlakini = disableKlakini

	// Render SolarSystem AND trigger OOB refresh for bottom content
	return templ_render.Render(c, analysis.SolarSystemAndRefresh(solarProps, name, day))
}

func (h *NumerologyHandler) getBestNames(candidates []domain.SimilarNameResult, limit int, allowKlakini bool) ([]domain.SimilarNameResult, []domain.SimilarNameResult, int) {
	var top4 []domain.SimilarNameResult
	var last4 []domain.SimilarNameResult

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

	// FALLBACK: If we have very few results (e.g. < 4 for Top 4), just take whatever we have from candidates
	// This ensures on Localhost/Dev or with bad data we still see SOMETHING.
	if len(finalList) < 4 {
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
		if len(finalList)+len(fallback) < 4 && !allowKlakini {
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

		// Fill up to 4 or limit
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

	// Fallback if no names found (or very few)
	if len(accumulatedNames) < 20 {
		preferredConsonant := h.findBestConsonant(name, day)
		// If klakini allowed, we can just pick the first char
		if repoAllowKlakini && preferredConsonant == "" && len([]rune(name)) > 0 {
			runes := []rune(name)
			// Skip vowels roughly
			if len(runes) > 0 {
				preferredConsonant = string(runes[0])
			}
		}

		fallbackLimit := 100 - len(accumulatedNames)
		var excluded []int
		for _, n := range accumulatedNames {
			excluded = append(excluded, n.NameID)
		}

		fallbackNames, err := h.namesMiracleRepo.GetFallbackNames(name, preferredConsonant, day, fallbackLimit, repoAllowKlakini, excluded)
		if err == nil && len(fallbackNames) > 0 {
			h.calculateScoresAndHighlights(fallbackNames, day)
			accumulatedNames = append(accumulatedNames, fallbackNames...)
		} else if err != nil {
			log.Printf("Fallback search failed: %v", err)
		}
	}

	return accumulatedNames, nil
}

func getMeaningsAndScores(pairs []string, pairCache *cache.NumberPairCache) ([]domain.PairMeaningResult, int, int) {
	var meanings []domain.PairMeaningResult
	var posScore, negScore int
	for _, p := range pairs {
		if meaning, ok := pairCache.GetMeaning(p); ok {
			// Force RED color for bad pairs to fix "sad brown" display issue globally
			if service.IsBadPairType(meaning.PairType) {
				meaning.Color = "#D32F2F"
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
	for cat := range counts {
		categoryKeywords[cat] = make(map[string]bool)
	}

	updateBreakdown := func(pairNumber string) {
		// Get categories directly from cache (sourced ONLY from number_categories table)
		if cats, ok := h.numberCategoryCache.GetCategories(pairNumber); ok {
			keywords := h.numberCategoryCache.GetKeywords(pairNumber)

			for _, c := range cats {
				// Only process allowed known categories for consistency
				if !allowedCategories[c] {
					continue
				}

				counts[c]++

				// Get number_type strictly from number_categories table via cache
				numberType := h.numberCategoryCache.GetNumberType(pairNumber)

				// Update Good/Bad counts based on number_type
				current := breakdown[c]
				if numberType == "ดี" {
					current.Good++
				} else if numberType == "ร้าย" {
					current.Bad++
				}

				// Aggregate keywords
				for _, kw := range keywords {
					if kw != "" {
						categoryKeywords[c][kw] = true
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
			breakdown[cat] = entry
		}
	}

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
		CategoryCounts:       counts,
		CategoryBreakdown:    breakdown,
	}, nil
}
