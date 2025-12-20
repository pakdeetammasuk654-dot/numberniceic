package handler

import (
	"net/url"
	"numberniceic/internal/core/service"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type ArticleHandler struct {
	service *service.ArticleService
	store   *session.Store
}

func NewArticleHandler(service *service.ArticleService, store *session.Store) *ArticleHandler {
	return &ArticleHandler{
		service: service,
		store:   store,
	}
}

func (h *ArticleHandler) ShowArticlesPage(c *fiber.Ctx) error {
	articles, err := h.service.GetAllArticles()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading articles")
	}

	return c.Render("articles", fiber.Map{
		"title":      "บทความ",
		"Articles":   articles,
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"ActivePage": "articles",
	}, "layouts/main")
}

func (h *ArticleHandler) ShowArticleDetailPage(c *fiber.Ctx) error {
	slug := c.Params("slug")

	// Decode the slug to handle Thai characters correctly
	decodedSlug, err := url.QueryUnescape(slug)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).SendString("Invalid article slug")
	}

	article, err := h.service.GetArticleBySlug(decodedSlug)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading article")
	}
	if article == nil {
		return c.Status(fiber.StatusNotFound).SendString("Article not found")
	}

	return c.Render("article_detail", fiber.Map{
		"title":      article.Title,
		"Article":    article,
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"ActivePage": "articles",
	}, "layouts/main")
}
