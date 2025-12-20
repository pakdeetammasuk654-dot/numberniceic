package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type AdminService struct {
	memberRepo  ports.MemberRepository
	articleRepo ports.ArticleRepository
}

func NewAdminService(memberRepo ports.MemberRepository, articleRepo ports.ArticleRepository) *AdminService {
	return &AdminService{
		memberRepo:  memberRepo,
		articleRepo: articleRepo,
	}
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
