package ports

import "numberniceic/internal/core/domain"

type ArticleRepository interface {
	GetAllPublished() ([]domain.Article, error)
	GetBySlug(slug string) (*domain.Article, error)

	// Admin methods
	GetAll() ([]domain.Article, error)
	GetByID(id int) (*domain.Article, error)
	GetWithPagination(page, limit int) ([]domain.Article, int64, error)
	Create(article *domain.Article) error
	Update(article *domain.Article) error
	Delete(id int) error
	UpdatePinOrder(id int, order int) error
}
