package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type ArticleService struct {
	repo ports.ArticleRepository
}

func NewArticleService(repo ports.ArticleRepository) *ArticleService {
	return &ArticleService{repo: repo}
}

func (s *ArticleService) GetAllArticles() ([]domain.Article, error) {
	return s.repo.GetAllPublished()
}

func (s *ArticleService) GetArticleBySlug(slug string) (*domain.Article, error) {
	return s.repo.GetBySlug(slug)
}
