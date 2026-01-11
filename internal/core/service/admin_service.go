package service

import (
	"errors"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type AdminService struct {
	memberRepo       ports.MemberRepository
	articleRepo      ports.ArticleRepository
	sampleRepo       ports.SampleNamesRepository
	namesMiracleRepo ports.NamesMiracleRepository
	productRepo      ports.ProductRepository
	orderRepo        ports.OrderRepository
	numerologySvc    *NumerologyService
	phoneNumberSvc   *PhoneNumberService
	promoRepo        ports.PromotionalCodeRepository
}

func NewAdminService(
	memberRepo ports.MemberRepository,
	articleRepo ports.ArticleRepository,
	sampleRepo ports.SampleNamesRepository,
	namesMiracleRepo ports.NamesMiracleRepository,
	productRepo ports.ProductRepository,
	orderRepo ports.OrderRepository,
	numerologySvc *NumerologyService,
	phoneNumberSvc *PhoneNumberService,
	promoRepo ports.PromotionalCodeRepository,
) *AdminService {
	return &AdminService{
		memberRepo:       memberRepo,
		articleRepo:      articleRepo,
		sampleRepo:       sampleRepo,
		namesMiracleRepo: namesMiracleRepo,
		productRepo:      productRepo,
		orderRepo:        orderRepo,
		numerologySvc:    numerologySvc,
		phoneNumberSvc:   phoneNumberSvc,
		promoRepo:        promoRepo,
	}
}

func (s *AdminService) GetSellNumbers() ([]domain.PhoneNumberAnalysis, error) {
	return s.phoneNumberSvc.GetSellNumbers()
}

func (s *AdminService) GetSellNumbersPaged(page, pageSize int) (domain.PagedPhoneNumberAnalysis, error) {
	return s.phoneNumberSvc.GetSellNumbersPaged(page, pageSize)
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

func (s *AdminService) GetMemberByUsername(username string) (*domain.Member, error) {
	return s.memberRepo.GetByUsername(username)
}

func (s *AdminService) UpdateAssignedColors(id int, colors string) error {
	return s.memberRepo.UpdateAssignedColors(id, colors)
}

func (s *AdminService) GetMembersWithAssignedColors() ([]domain.Member, error) {
	return s.memberRepo.GetMembersWithAssignedColors()
}

func (s *AdminService) SearchMembers(query string) ([]domain.Member, error) {
	return s.memberRepo.SearchMembers(query)
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

// --- Product Management ---

func (s *AdminService) GetAllProducts() ([]domain.Product, error) {
	return s.productRepo.GetAll()
}

func (s *AdminService) GetProductByID(id int) (*domain.Product, error) {
	return s.productRepo.GetByID(id)
}

func (s *AdminService) CreateProduct(product *domain.Product) error {
	return s.productRepo.Create(product)
}

func (s *AdminService) UpdateProduct(product *domain.Product) error {
	return s.productRepo.Update(product)
}

func (s *AdminService) DeleteProduct(id int) error {
	return s.productRepo.Delete(id)
}

// --- Order Management ---

func (s *AdminService) GetAllOrders() ([]domain.Order, error) {
	return s.orderRepo.GetAll()
}

func (s *AdminService) GetOrdersPaginated(page, limit int, search string) ([]domain.Order, int64, error) {
	offset := (page - 1) * limit
	return s.orderRepo.GetWithPagination(limit, offset, search)
}

func (s *AdminService) DeleteOrder(id int) error {
	return s.orderRepo.Delete(id)
}

// --- Promotional Code Management ---

func (s *AdminService) GetAllPromotionalCodes() ([]domain.PromotionalCode, error) {
	return s.promoRepo.GetAll()
}

func (s *AdminService) GenerateVIPCode(code string) error {
	return s.promoRepo.GenerateCode(code)
}

func (s *AdminService) BlockUserByVIPCode(code string) error {
	return s.SetUserStatusByVIPCode(code, -1) // -1 is Banned
}

func (s *AdminService) SetUserStatusByVIPCode(code string, status int) error {
	pc, err := s.promoRepo.GetByCode(code)
	if err != nil {
		return err
	}
	if pc.UsedByMemberID == nil {
		return errors.New("code has not been used yet")
	}
	return s.memberRepo.UpdateStatus(*pc.UsedByMemberID, status)
}
