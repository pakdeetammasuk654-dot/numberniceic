package handler

import (
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/views/layout"
	"numberniceic/views/pages/admin"

	"github.com/gofiber/fiber/v2"
)

// SendArticleNotificationPage shows the form to send article notifications
func (h *AdminHandler) SendArticleNotificationPage(c *fiber.Ctx) error {
	// Get all articles
	articles, err := h.articleService.GetAllArticles()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading articles")
	}

	successMsg := c.Query("success")
	errorMsg := c.Query("error")
	avatarURL, _ := c.Locals("AvatarURL").(string)

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{Title: "ส่งการแจ้งเตือนบทความ", OGType: "website"},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		false, "admin", successMsg, errorMsg, avatarURL,
		admin.SendArticleNotificationForm(articles, successMsg, errorMsg),
	))
}

// SendArticleNotificationPost handles sending article notifications
func (h *AdminHandler) SendArticleNotificationPost(c *fiber.Ctx) error {
	articleSlug := c.FormValue("article_slug")
	customTitle := c.FormValue("custom_title")
	customMessage := c.FormValue("custom_message")

	if articleSlug == "" {
		return c.Redirect("/admin/send-article-notification?error=กรุณาเลือกบทความ")
	}

	// Get article details
	article, err := h.articleService.GetArticleBySlug(articleSlug)
	if err != nil {
		return c.Redirect("/admin/send-article-notification?error=ไม่พบบทความที่เลือก")
	}

	// Use custom title/message or default from article
	title := customTitle
	if title == "" {
		title = "บทความใหม่: " + article.Title
	}

	message := customMessage
	if message == "" {
		message = article.Excerpt
	}

	// Create data payload for article notification
	data := map[string]string{
		"type":         "article",
		"article_slug": articleSlug,
	}

	// Send broadcast notification with article data
	err = h.memberService.CreateBroadcastNotificationWithData(title, message, data)
	if err != nil {
		return c.Redirect("/admin/send-article-notification?error=" + err.Error())
	}

	return c.Redirect("/admin/send-article-notification?success=ส่งการแจ้งเตือนบทความให้ทุกคนเรียบร้อยแล้ว")
}
