package handler

import (
	"encoding/xml"
	"fmt"
	"numberniceic/internal/core/service"
	"time"

	"github.com/gofiber/fiber/v2"
)

type SEOHandler struct {
	articleService *service.ArticleService
}

func NewSEOHandler(articleService *service.ArticleService) *SEOHandler {
	return &SEOHandler{
		articleService: articleService,
	}
}

type URL struct {
	Loc        string  `xml:"loc"`
	LastMod    string  `xml:"lastmod,omitempty"`
	ChangeFreq string  `xml:"changefreq,omitempty"`
	Priority   float64 `xml:"priority,omitempty"`
}

type URLSet struct {
	XMLName xml.Name `xml:"urlset"`
	XMLNS   string   `xml:"xmlns,attr"`
	URLs    []URL    `xml:"url"`
}

func (h *SEOHandler) GetSitemap(c *fiber.Ctx) error {
	baseURL := "https://xn--b3cu8e7ah6h.com"
	now := time.Now().Format("2006-01-02")

	urls := []URL{
		{Loc: baseURL + "/", LastMod: now, ChangeFreq: "daily", Priority: 1.0},
		{Loc: baseURL + "/shop", LastMod: now, ChangeFreq: "daily", Priority: 0.9},
		{Loc: baseURL + "/analyzer", LastMod: now, ChangeFreq: "monthly", Priority: 0.9},
		{Loc: baseURL + "/articles", LastMod: now, ChangeFreq: "daily", Priority: 0.8},
		{Loc: baseURL + "/about", LastMod: now, ChangeFreq: "monthly", Priority: 0.5},
		{Loc: baseURL + "/login", LastMod: now, ChangeFreq: "monthly", Priority: 0.3},
		{Loc: baseURL + "/register", LastMod: now, ChangeFreq: "monthly", Priority: 0.3},
	}

	// Add dynamic articles
	articles, err := h.articleService.GetAllArticles()
	if err == nil {
		for _, art := range articles {
			urls = append(urls, URL{
				Loc:      fmt.Sprintf("%s/articles/%s", baseURL, art.Slug),
				LastMod:  art.PublishedAt.Format("2006-01-02"),
				Priority: 0.7,
			})
		}
	}

	// --- DUMMY/MISSING PARTS FOR SEO ---
	// Add dummy category pages if they were missing
	categories := []string{"ber-mongkol", "ber-vip", "ber-phlang-ngao"}
	for _, cat := range categories {
		urls = append(urls, URL{
			Loc:        fmt.Sprintf("%s/shop/category/%s", baseURL, cat),
			LastMod:    now,
			ChangeFreq: "weekly",
			Priority:   0.6,
		})
	}

	sitemap := URLSet{
		XMLNS: "http://www.sitemaps.org/schemas/sitemap/0.9",
		URLs:  urls,
	}

	c.Set(fiber.HeaderContentType, fiber.MIMEApplicationXML)

	// Write XML declaration manually because Marshaler doesn't add it
	_, err = c.Write([]byte(xml.Header))
	if err != nil {
		return err
	}

	return xml.NewEncoder(c).Encode(sitemap)
}

func (h *SEOHandler) GetRobots(c *fiber.Ctx) error {
	content := "User-agent: *\nAllow: /\n\nSitemap: https://xn--b3cu8e7ah6h.com/sitemap.xml"
	c.Set(fiber.HeaderContentType, fiber.MIMETextPlain)
	return c.SendString(content)
}
