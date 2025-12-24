package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type AdminService struct {
	memberRepo       ports.MemberRepository
	articleRepo      ports.ArticleRepository
	sampleRepo       ports.SampleNamesRepository
	namesMiracleRepo ports.NamesMiracleRepository
	numerologySvc    *NumerologyService
}

func NewAdminService(
	memberRepo ports.MemberRepository,
	articleRepo ports.ArticleRepository,
	sampleRepo ports.SampleNamesRepository,
	namesMiracleRepo ports.NamesMiracleRepository,
	numerologySvc *NumerologyService,
) *AdminService {
	return &AdminService{
		memberRepo:       memberRepo,
		articleRepo:      articleRepo,
		sampleRepo:       sampleRepo,
		namesMiracleRepo: namesMiracleRepo,
		numerologySvc:    numerologySvc,
	}
}

func (s *AdminService) AddSystemName(name string) error {
	details := s.numerologySvc.CalculateNameDetails(name)
	return s.namesMiracleRepo.Create(details)
}

func (s *AdminService) AddSystemNamesBulk(names []string) (int, int) {
	successCount := 0
	failCount := 0

	for _, name := range names {
		trimmedName := SanitizeInput(name)
		if trimmedName == "" {
			continue // Skip empty results after sanitization
		}

		err := s.AddSystemName(trimmedName)
		if err != nil {
			// If it's an error (duplicate or other), we count as fail and move to next
			failCount++
			continue
		}
		successCount++
	}

	return successCount, failCount
}

func (s *AdminService) GetLatestSystemNames(limit int) ([]domain.SimilarNameResult, error) {
	return s.namesMiracleRepo.GetLatest(limit)
}

func (s *AdminService) GetTotalNamesCount() (int, error) {
	return s.namesMiracleRepo.Count()
}

func (s *AdminService) DeleteSystemName(id int) error {
	return s.namesMiracleRepo.Delete(id)
}

// --- Sample Names Management ---

func (s *AdminService) GetAllSampleNames() ([]domain.SampleName, error) {
	return s.sampleRepo.GetAll()
}

func (s *AdminService) SetActiveSampleName(id int) error {
	return s.sampleRepo.SetActive(id)
}

// --- User Management ---

func (s *AdminService) GetAllUsers() ([]domain.Member, error) {
	return s.memberRepo.GetAllMembers()
}

func (s *AdminService) UpdateUserStatus(id int, status int) error {
	return s.memberRepo.UpdateStatus(id, status)
}

func (s *AdminService) DeleteUser(id int) error {
	return s.memberRepo.Delete(id)
}

func (s *AdminService) GetMemberByID(id int) (*domain.Member, error) {
	return s.memberRepo.GetByID(id)
}

// --- Article Management ---

func (s *AdminService) GetAllArticles() ([]domain.Article, error) {
	return s.articleRepo.GetAll()
}

func (s *AdminService) GetArticlesPaginated(page, limit int) ([]domain.Article, int64, error) {
	return s.articleRepo.GetWithPagination(page, limit)
}

func (s *AdminService) GetArticleByID(id int) (*domain.Article, error) {
	return s.articleRepo.GetByID(id)
}

func (s *AdminService) CreateArticle(article *domain.Article) error {
	return s.articleRepo.Create(article)
}

func (s *AdminService) UpdateArticle(article *domain.Article) error {
	return s.articleRepo.Update(article)
}

func (s *AdminService) DeleteArticle(id int) error {
	return s.articleRepo.Delete(id)
}

func (s *AdminService) UpdateArticlePinOrder(id int, order int) error {
	return s.articleRepo.UpdatePinOrder(id, order)
}
