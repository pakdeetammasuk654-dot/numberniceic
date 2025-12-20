package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresArticleRepository struct {
	db *sql.DB
}

func NewPostgresArticleRepository(db *sql.DB) ports.ArticleRepository {
	return &PostgresArticleRepository{db: db}
}

func (r *PostgresArticleRepository) GetAllPublished() ([]domain.Article, error) {
	query := `
		SELECT art_id, slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, COALESCE(pin_order, 0)
		FROM articles
		WHERE is_published = true
		ORDER BY 
			CASE WHEN COALESCE(pin_order, 0) > 0 THEN pin_order ELSE 999 END ASC,
			published_at DESC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var articles []domain.Article
	for rows.Next() {
		var a domain.Article
		err := rows.Scan(&a.ID, &a.Slug, &a.Title, &a.Excerpt, &a.Category, &a.ImageURL, &a.PublishedAt, &a.IsPublished, &a.Content, &a.TitleShort, &a.PinOrder)
		if err != nil {
			return nil, err
		}
		articles = append(articles, a)
	}
	return articles, nil
}

func (r *PostgresArticleRepository) GetBySlug(slug string) (*domain.Article, error) {
	query := `
		SELECT art_id, slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, COALESCE(pin_order, 0)
		FROM articles
		WHERE slug = $1 AND is_published = true
	`
	var a domain.Article
	err := r.db.QueryRow(query, slug).Scan(&a.ID, &a.Slug, &a.Title, &a.Excerpt, &a.Category, &a.ImageURL, &a.PublishedAt, &a.IsPublished, &a.Content, &a.TitleShort, &a.PinOrder)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // Not found
		}
		return nil, err
	}
	return &a, nil
}

// --- Admin Methods ---

func (r *PostgresArticleRepository) GetAll() ([]domain.Article, error) {
	query := `
		SELECT art_id, slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, COALESCE(pin_order, 0)
		FROM articles
		ORDER BY 
			CASE WHEN COALESCE(pin_order, 0) > 0 THEN pin_order ELSE 999 END ASC,
			art_id DESC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var articles []domain.Article
	for rows.Next() {
		var a domain.Article
		err := rows.Scan(&a.ID, &a.Slug, &a.Title, &a.Excerpt, &a.Category, &a.ImageURL, &a.PublishedAt, &a.IsPublished, &a.Content, &a.TitleShort, &a.PinOrder)
		if err != nil {
			return nil, err
		}
		articles = append(articles, a)
	}
	return articles, nil
}

func (r *PostgresArticleRepository) GetByID(id int) (*domain.Article, error) {
	query := `
		SELECT art_id, slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, COALESCE(pin_order, 0)
		FROM articles
		WHERE art_id = $1
	`
	var a domain.Article
	err := r.db.QueryRow(query, id).Scan(&a.ID, &a.Slug, &a.Title, &a.Excerpt, &a.Category, &a.ImageURL, &a.PublishedAt, &a.IsPublished, &a.Content, &a.TitleShort, &a.PinOrder)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &a, nil
}

func (r *PostgresArticleRepository) GetWithPagination(page, limit int) ([]domain.Article, int64, error) {
	offset := (page - 1) * limit
	query := `
		SELECT art_id, slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, COALESCE(pin_order, 0)
		FROM articles
		ORDER BY 
			CASE WHEN COALESCE(pin_order, 0) > 0 THEN pin_order ELSE 999 END ASC,
			art_id DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var articles []domain.Article
	for rows.Next() {
		var a domain.Article
		err := rows.Scan(&a.ID, &a.Slug, &a.Title, &a.Excerpt, &a.Category, &a.ImageURL, &a.PublishedAt, &a.IsPublished, &a.Content, &a.TitleShort, &a.PinOrder)
		if err != nil {
			return nil, 0, err
		}
		articles = append(articles, a)
	}

	// Get total count
	var totalCount int64
	countQuery := `SELECT COUNT(*) FROM articles`
	err = r.db.QueryRow(countQuery).Scan(&totalCount)
	if err != nil {
		return nil, 0, err
	}

	return articles, totalCount, nil
}

func (r *PostgresArticleRepository) Create(article *domain.Article) error {
	query := `
		INSERT INTO articles (slug, title, excerpt, category, image_url, published_at, is_published, content, title_short, pin_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING art_id
	`
	return r.db.QueryRow(query, article.Slug, article.Title, article.Excerpt, article.Category, article.ImageURL, time.Now(), article.IsPublished, article.Content, article.TitleShort, article.PinOrder).Scan(&article.ID)
}

func (r *PostgresArticleRepository) Update(article *domain.Article) error {
	query := `
		UPDATE articles
		SET slug = $1, title = $2, excerpt = $3, category = $4, image_url = $5, is_published = $6, content = $7, title_short = $8, pin_order = $9
		WHERE art_id = $10
	`
	_, err := r.db.Exec(query, article.Slug, article.Title, article.Excerpt, article.Category, article.ImageURL, article.IsPublished, article.Content, article.TitleShort, article.PinOrder, article.ID)
	return err
}

func (r *PostgresArticleRepository) Delete(id int) error {
	query := `DELETE FROM articles WHERE art_id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *PostgresArticleRepository) UpdatePinOrder(id int, order int) error {
	// If order is > 0, we might want to clear other article with same order (optional, but good for unique ranking)
	// For simplicity, let's just update.
	query := `UPDATE articles SET pin_order = $1 WHERE art_id = $2`
	_, err := r.db.Exec(query, order, id)
	return err
}
