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
		"บทความ",
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
		article.Title,
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"articles",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.ArticleDetail(article),
	))
}
