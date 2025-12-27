package handler

import (
	"fmt"
	"net/url"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/service"
	"numberniceic/views/layout"
	"numberniceic/views/pages"

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

	// Helper to get string from Locals safely
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:       "บทความให้ความรู้อันเป็นมงคล",
			Description: "คลังบทความเกี่ยวกับชื่อมงคล เลขศาสตร์ และความเชื่อโบราณ เพื่อเป็นแนวทางในการเลือกชื่อที่ดีที่สุดให้กับคุณและคนที่คุณรัก",
			Keywords:    "บทความชื่อมงคล, ความรู้เรื่องชื่อ, เลขศาสตร์มงคล, พลังเงา",
			Canonical:   "https://xn--b3cu8e7ah6h.com/articles",
			OGImage:     "https://xn--b3cu8e7ah6h.com/static/og-articles.png",
			OGType:      "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"articles",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Articles(articles),
	))
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

	// Helper to get string from Locals safely
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:       article.Title,
			Description: article.Excerpt,
			Keywords:    article.Category + ", " + article.Title,
			Canonical:   fmt.Sprintf("https://xn--b3cu8e7ah6h.com/articles/%s", url.PathEscape(article.Slug)),
			OGImage:     article.ImageURL,
			OGType:      "article",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"articles",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.ArticleDetail(article),
	))
}

// GetArticlesJSON returns articles in JSON format for API consumers
func (h *ArticleHandler) GetArticlesJSON(c *fiber.Ctx) error {
	articles, err := h.service.GetAllArticles()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Error loading articles",
		})
	}
	return c.JSON(articles)
}

// GetArticleBySlugJSON returns a single article in JSON format for API consumers
func (h *ArticleHandler) GetArticleBySlugJSON(c *fiber.Ctx) error {
	slug := c.Params("slug")

	// Decode the slug to handle Thai characters correctly
	decodedSlug, err := url.QueryUnescape(slug)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid article slug",
		})
	}

	article, err := h.service.GetArticleBySlug(decodedSlug)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Error loading article",
		})
	}
	if article == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Article not found",
		})
	}

	return c.JSON(article)
}
