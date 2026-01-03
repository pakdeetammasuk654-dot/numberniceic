package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"sort"
	"strings"
)

type PhoneNumberService struct {
	repo      ports.PhoneNumberRepository
	pairRepo  ports.NumberPairRepository
	pairCache map[string]domain.NumberPairMeaning
}

func NewPhoneNumberService(repo ports.PhoneNumberRepository, pairRepo ports.NumberPairRepository) *PhoneNumberService {
	s := &PhoneNumberService{
		repo:      repo,
		pairRepo:  pairRepo,
		pairCache: make(map[string]domain.NumberPairMeaning),
	}
	s.ReloadCache()
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

func (s *PhoneNumberService) GetLuckyNumberByCategory(category string) (string, []string, error) {
	numbers, err := s.repo.GetAll()
	if err != nil {
		return "", nil, err
	}

	category = strings.TrimSpace(category)
	var matchingNumbers []struct {
		num      domain.PhoneNumberSell
		keywords []string
	}

	// Filter numbers by category meaning of their sum
	for _, num := range numbers {
		sumKey := strings.TrimSpace(num.PNumberSum)
		meaning, ok := s.pairCache[sumKey]
		if ok {
			meaningCat := strings.TrimSpace(meaning.Category)
			if meaningCat == category {
				matchingNumbers = append(matchingNumbers, struct {
					num      domain.PhoneNumberSell
					keywords []string
				}{num, meaning.Keywords})
			}
		}
	}

	if len(matchingNumbers) == 0 {
		return "", nil, nil
	}

	// Sort matching numbers by price descending
	sort.Slice(matchingNumbers, func(i, j int) bool {
		return matchingNumbers[i].num.PNumberPrice > matchingNumbers[j].num.PNumberPrice
	})

	return matchingNumbers[0].num.PNumberNum, matchingNumbers[0].keywords, nil
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
