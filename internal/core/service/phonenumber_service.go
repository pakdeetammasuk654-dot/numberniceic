package service

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"sort"
	"strconv"
	"strings"
)

type PhoneNumberService struct {
	repo        ports.PhoneNumberRepository
	pairRepo    ports.NumberPairRepository
	pairCache   map[string]domain.NumberPairMeaning
	aspectCache map[string]map[string]AspectData // pair -> category -> data
}

type AspectData struct {
	Percentage int
	Insight    string
}

// JSON Structure for numbers.json
type NumbersJSON struct {
	Numbers map[string]NumberDetail `json:"numbers"`
}

type NumberDetail struct {
	Aspects map[string]AspectDetail `json:"aspects"`
}

type AspectDetail struct {
	Percentage int    `json:"percentage"`
	Insight    string `json:"insight"`
}

func NewPhoneNumberService(repo ports.PhoneNumberRepository, pairRepo ports.NumberPairRepository) *PhoneNumberService {
	s := &PhoneNumberService{
		repo:        repo,
		pairRepo:    pairRepo,
		pairCache:   make(map[string]domain.NumberPairMeaning),
		aspectCache: make(map[string]map[string]AspectData),
	}
	s.ReloadCache()
	s.LoadAspectsFromJSON("numbers.json") // Load from root
	return s
}

func (s *PhoneNumberService) ReloadCache() {
	pairs, err := s.pairRepo.GetAll()
	if err == nil {
		for _, p := range pairs {
			s.pairCache[p.PairNumber] = p
		}
	}
}

func (s *PhoneNumberService) LoadAspectsFromJSON(filePath string) {
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		// Fallback for different execution contexts or Docker paths
		data, err = ioutil.ReadFile("assets/numbers.json")
		if err != nil {
			log.Printf("Warning: Could not load numbers.json for aspects: %v", err)
			return
		}
	}

	var parsed NumbersJSON
	if err := json.Unmarshal(data, &parsed); err != nil {
		log.Printf("Error parsing numbers.json: %v", err)
		return
	}

	for pair, detail := range parsed.Numbers {
		aspects := make(map[string]AspectData)
		for key, aspect := range detail.Aspects {
			aspects[key] = AspectData{
				Percentage: aspect.Percentage,
				Insight:    aspect.Insight,
			}
		}
		s.aspectCache[pair] = aspects
	}
	log.Printf("Loaded aspects using Struct for %d pairs", len(s.aspectCache))
}

func (s *PhoneNumberService) GetSellNumbersPaged(page, pageSize int) (domain.PagedPhoneNumberAnalysis, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}

	offset := (page - 1) * pageSize
	numbers, err := s.repo.GetPaged(offset, pageSize)
	if err != nil {
		return domain.PagedPhoneNumberAnalysis{}, err
	}

	totalCount, err := s.repo.Count()
	if err != nil {
		return domain.PagedPhoneNumberAnalysis{}, err
	}

	var items []domain.PhoneNumberAnalysis
	for _, num := range numbers {
		items = append(items, s.AnalyzeNumber(num))
	}

	totalPages := (totalCount + pageSize - 1) / pageSize

	return domain.PagedPhoneNumberAnalysis{
		Items:       items,
		TotalCount:  totalCount,
		CurrentPage: page,
		PageSize:    pageSize,
		TotalPages:  totalPages,
	}, nil
}

func (s *PhoneNumberService) AnalyzeNumber(num domain.PhoneNumberSell) domain.PhoneNumberAnalysis {
	cleaned := strings.ReplaceAll(num.PNumberNum, "-", "")
	cleaned = strings.TrimSpace(cleaned)

	var primaryPairs []domain.PhoneNumberPairMeaning
	var secondaryPairs []domain.PhoneNumberPairMeaning
	totalScore := 0

	if len(cleaned) >= 2 {
		for i := 0; i < len(cleaned)-1; i++ {
			p := cleaned[i : i+2]
			meaning, ok := s.pairCache[p]
			if !ok {
				meaning = domain.NumberPairMeaning{
					PairNumber: p,
					Color:      "#9E9E9E",
				}
			}
			if meaning.Color == "" {
				meaning.Color = GetPairTypeColor(meaning.PairType)
			}

			pairMeaning := domain.PhoneNumberPairMeaning{
				Pair:    p,
				Meaning: meaning,
			}

			if i%2 == 0 {
				primaryPairs = append(primaryPairs, pairMeaning)
			} else {
				secondaryPairs = append(secondaryPairs, pairMeaning)
			}
			totalScore += meaning.PairPoint
		}
	}

	sumMeaning, ok := s.pairCache[num.PNumberSum]
	if !ok {
		sumMeaning = domain.NumberPairMeaning{
			PairNumber: num.PNumberSum,
			Color:      "#9E9E9E",
		}
	}
	if sumMeaning.Color == "" {
		sumMeaning.Color = GetPairTypeColor(sumMeaning.PairType)
	}

	return domain.PhoneNumberAnalysis{
		PhoneNumber:    num,
		PrimaryPairs:   primaryPairs,
		SecondaryPairs: secondaryPairs,
		SumMeaning:     sumMeaning,
		TotalScore:     totalScore,
	}
}

func (s *PhoneNumberService) GetSellNumbers() ([]domain.PhoneNumberAnalysis, error) {
	numbers, err := s.repo.GetAll()
	if err != nil {
		return nil, err
	}

	var results []domain.PhoneNumberAnalysis
	for _, num := range numbers {
		results = append(results, s.AnalyzeNumber(num))
	}
	return results, nil
}

// Map Thai category names to English keys used in numbers.json
func mapCategoryToKey(category string) string {
	switch category {
	case "การงาน":
		return "career"
	case "การเงิน":
		return "finance"
	case "ความรัก":
		return "love"
	case "สุขภาพ":
		return "health"
	default:
		return strings.ToLower(category)
	}
}

func (s *PhoneNumberService) CalculateWeightedCategoryScore(numberStr string, category string) float64 {
	key := mapCategoryToKey(category)

	// Analyze pairs
	mainPairs, hiddenPairs, sumMeaning := s.AnalyzeRawNumber(numberStr)

	// Weights Configuration
	// Phone A: 05, 05, 10, 15, 20
	mainWeights := []float64{0.05, 0.05, 0.10, 0.15, 0.20}
	// Phone B: 03, 05, 05, 12
	hiddenWeights := []float64{0.03, 0.05, 0.05, 0.12}
	sumWeight := 0.20

	totalScore := 0.0

	getPercent := func(pair string) float64 {
		// Check if pair is Bad (R-type)
		if meaning, ok := s.pairCache[pair]; ok {
			if strings.HasPrefix(meaning.PairType, "R") {
				return -50.0 // Heavy penalty for bad pairs in a lucky number
			}
			// Only count positive score if it's a D-type or Neutral with good aspect
			if !strings.HasPrefix(meaning.PairType, "D") && meaning.PairPoint < 0 {
				return 0.0 // Don't allow negative impact pairs to contribute positive score
			}
		}

		if aspects, ok := s.aspectCache[pair]; ok {
			if val, ok := aspects[key]; ok {
				return float64(val.Percentage)
			}
		}
		return 0.0
	}

	// Calculate Main Pairs (Phone A)
	for i, p := range mainPairs {
		if i < len(mainWeights) {
			pct := getPercent(p.Pair)
			totalScore += pct * mainWeights[i]
		}
	}

	// Calculate Hidden Pairs (Phone B)
	for i, p := range hiddenPairs {
		if i < len(hiddenWeights) {
			pct := getPercent(p.Pair)
			totalScore += pct * hiddenWeights[i]
		}
	}

	// Calculate Sum
	sumPct := getPercent(sumMeaning.Pair)
	totalScore += sumPct * sumWeight

	return totalScore
}

func (s *PhoneNumberService) GetLuckyNumberByCategory(category string, index int) (string, string, []string, error) {
	numbers, err := s.repo.GetAll()
	if err != nil {
		return "", "", nil, err
	}

	category = strings.TrimSpace(category)
	categoryKey := mapCategoryToKey(category)

	type scoredNumber struct {
		num      domain.PhoneNumberSell
		keywords []string
		wtScore  float64
	}

	var matchingNumbers []scoredNumber

	// Calculate weighted score for ALL numbers for this specific category
	for _, num := range numbers {
		// 1. HARD FILTER: A "Lucky Number" must NOT contain any R-type (Bad) pairs
		// This prevents %ร้าย from appearing in the chart.
		cleaned := strings.ReplaceAll(num.PNumberNum, "-", "")
		hasBadPair := false
		for i := 0; i < len(cleaned)-1; i++ {
			p := cleaned[i : i+2]
			if meaning, ok := s.pairCache[p]; ok {
				if strings.HasPrefix(meaning.PairType, "R") {
					hasBadPair = true
					break
				}
			}
		}
		// Also check sum
		if meaning, ok := s.pairCache[num.PNumberSum]; ok {
			if strings.HasPrefix(meaning.PairType, "R") {
				hasBadPair = true
			}
		}

		if hasBadPair {
			continue // Skip numbers with any bad pairs for enhancement
		}

		wtScore := s.CalculateWeightedCategoryScore(num.PNumberNum, category)

		sumKey := strings.TrimSpace(num.PNumberSum)

		// Priority: Aspect Insight > Sum Meaning Keywords
		var finalKeywords []string
		var insightText string

		// Try to get Insight from Aspect Cache (numbers.json)
		if aspects, ok := s.aspectCache[sumKey]; ok {
			if data, ok := aspects[categoryKey]; ok {
				if data.Insight != "" {
					insightText = data.Insight
					// Use the insight as the keyword/description
					finalKeywords = []string{data.Insight}
				}
			}
		}

		// Filter out numbers with Negative Insights for the requested category
		if insightText != "" {
			negativeKeywords := []string{"ระวัง", "อุบัติเหตุ", "ร้าย", "ไม่ดี", "เสีย", "แย่", "ปัญหาสุขภาพ", "โรค"}
			isNegative := false
			for _, neg := range negativeKeywords {
				if strings.Contains(insightText, neg) {
					isNegative = true
					break
				}
			}
			if isNegative {
				continue // Skip this number
			}
		}

		// Fallback to generic keywords if no insight found
		if len(finalKeywords) == 0 {
			if meaning, ok := s.pairCache[sumKey]; ok {
				if len(meaning.Keywords) > 0 {
					finalKeywords = meaning.Keywords
				}
			}
		}

		if wtScore > 5.0 { // Minimum score threshold for "Good" numbers
			matchingNumbers = append(matchingNumbers, scoredNumber{num, finalKeywords, wtScore})
		}
	}

	if len(matchingNumbers) == 0 {
		return "", "", nil, nil
	}

	// Sort by Weighted Score DESC, then Price DESC
	sort.Slice(matchingNumbers, func(i, j int) bool {
		if matchingNumbers[i].wtScore != matchingNumbers[j].wtScore {
			return matchingNumbers[i].wtScore > matchingNumbers[j].wtScore
		}
		return matchingNumbers[i].num.PNumberPrice > matchingNumbers[j].num.PNumberPrice
	})

	if index < 0 {
		index = 0
	}
	selectedIndex := index % len(matchingNumbers)

	return matchingNumbers[selectedIndex].num.PNumberNum, matchingNumbers[selectedIndex].num.PNumberSum, matchingNumbers[selectedIndex].keywords, nil
}

func (s *PhoneNumberService) ExtractPairs(num string) []string {
	var pairs []string
	cleaned := strings.ReplaceAll(num, "-", "")
	cleaned = strings.TrimSpace(cleaned)
	if len(cleaned) < 2 {
		return pairs
	}
	for i := 0; i < len(cleaned)-1; i++ {
		pairs = append(pairs, cleaned[i:i+2])
	}
	return pairs
}

// AnalyzeRawNumber analyzes a raw phone number string (e.g. "0859995924")
// and returns the main pairs, hidden pairs, and sum meaning with colors.
func (s *PhoneNumberService) AnalyzeRawNumber(number string) (mainPairs []domain.PhoneNumberPairMeaning, hiddenPairs []domain.PhoneNumberPairMeaning, sumMeaning domain.PhoneNumberPairMeaning) {
	cleaned := strings.ReplaceAll(number, "-", "")
	cleaned = strings.TrimSpace(cleaned)

	n := len(cleaned)

	getPairMeaning := func(p string) domain.PhoneNumberPairMeaning {
		meaning, ok := s.pairCache[p]
		if !ok {
			meaning = domain.NumberPairMeaning{
				PairNumber: p,
				Color:      "#9E9E9E",
			}
		}
		if meaning.Color == "" {
			meaning.Color = GetPairTypeColor(meaning.PairType)
		}
		return domain.PhoneNumberPairMeaning{
			Pair:    p,
			Meaning: meaning,
		}
	}

	// Calculate Main Pairs (01, 23, 45...)
	for i := 0; i < n; i += 2 {
		if i+1 < n {
			p := cleaned[i : i+2]
			mainPairs = append(mainPairs, getPairMeaning(p))
		}
	}

	// Calculate Hidden Pairs (12, 34, 56...)
	for i := 1; i < n; i += 2 {
		if i+1 < n {
			p := cleaned[i : i+2]
			hiddenPairs = append(hiddenPairs, getPairMeaning(p))
		}
	}

	// Calculate Sum
	sumVal := 0
	for _, r := range cleaned {
		if r >= '0' && r <= '9' {
			sumVal += int(r - '0')
		}
	}
	sumStr := strconv.Itoa(sumVal)

	// Get Sum Meaning
	m, ok := s.pairCache[sumStr]
	if !ok {
		m = domain.NumberPairMeaning{
			PairNumber: sumStr,
			Color:      "#9E9E9E",
		}
	}
	if m.Color == "" {
		m.Color = GetPairTypeColor(m.PairType)
	}
	sumMeaning = domain.PhoneNumberPairMeaning{
		Pair:    sumStr,
		Meaning: m,
	}

	return mainPairs, hiddenPairs, sumMeaning
}
