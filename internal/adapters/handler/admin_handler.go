package handler

import (
	"fmt"
	"io/ioutil"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type AdminHandler struct {
	service *service.AdminService
}

func NewAdminHandler(service *service.AdminService) *AdminHandler {
	return &AdminHandler{service: service}
}

// --- Dashboard ---
func (h *AdminHandler) ShowDashboard(c *fiber.Ctx) error {
	return c.Render("admin_dashboard", fiber.Map{
		"title":      "Admin Dashboard",
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
	}, "layouts/main")
}

// --- User Management ---
func (h *AdminHandler) ShowUsersPage(c *fiber.Ctx) error {
	users, err := h.service.GetAllUsers()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading users")
	}
	return c.Render("admin_users", fiber.Map{
		"title":      "Manage Users",
		"Users":      users,
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
	}, "layouts/main")
}

func (h *AdminHandler) UpdateUserStatus(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	status, _ := strconv.Atoi(c.FormValue("status"))

	err := h.service.UpdateUserStatus(id, status)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error updating user status")
	}

	// Re-fetch the user to get updated data and re-render the row
	user, err := h.service.GetMemberByID(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error fetching updated user")
	}

	// Set a header to trigger a toast message on the client-side
	c.Set("HX-Trigger", "show-toast")
	// Render only the row partial
	return c.Render("partials/admin_user_row", user)
}

func (h *AdminHandler) DeleteUser(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.DeleteUser(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error deleting user")
	}
	return c.SendString("") // Remove row from DOM
}

// --- Article Management ---

func (h *AdminHandler) ShowArticlesPage(c *fiber.Ctx) error {
	articles, err := h.service.GetAllArticles()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading articles")
	}
	return c.Render("admin_articles", fiber.Map{
		"title":      "Manage Articles",
		"Articles":   articles,
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
	}, "layouts/main")
}

func (h *AdminHandler) ShowCreateArticlePage(c *fiber.Ctx) error {
	return c.Render("admin_article_form", fiber.Map{
		"title":      "Create Article",
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
		"IsEdit":     false,
		"TinyMCEKey": os.Getenv("TINY_MCE_KEY"),
	}, "layouts/main")
}

func (h *AdminHandler) CreateArticle(c *fiber.Ctx) error {
	// Handle Image Upload
	imageURL := ""
	file, err := c.FormFile("image_file")
	if err == nil {
		// Generate unique filename
		ext := filepath.Ext(file.Filename)
		filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		path := fmt.Sprintf("./static/uploads/%s", filename)

		// Save file
		if err := c.SaveFile(file, path); err != nil {
			return c.Status(fiber.StatusInternalServerError).SendString("Error saving image: " + err.Error())
		}
		imageURL = fmt.Sprintf("/uploads/%s", filename)
	} else {
		// Fallback to image_url input if no file uploaded
		imageURL = c.FormValue("image_url")
	}

	article := &domain.Article{
		Title:       c.FormValue("title"),
		Slug:        c.FormValue("slug"),
		Excerpt:     c.FormValue("excerpt"),
		Category:    c.FormValue("category"),
		ImageURL:    imageURL,
		Content:     c.FormValue("content"),
		TitleShort:  c.FormValue("title_short"),
		IsPublished: c.FormValue("is_published") == "on",
		PublishedAt: time.Now(),
	}

	err = h.service.CreateArticle(article)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error creating article: " + err.Error())
	}

	return c.Redirect("/admin/articles")
}

func (h *AdminHandler) ShowEditArticlePage(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	article, err := h.service.GetArticleByID(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading article")
	}
	if article == nil {
		return c.Status(fiber.StatusNotFound).SendString("Article not found")
	}

	return c.Render("admin_article_form", fiber.Map{
		"title":      "Edit Article",
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
		"IsEdit":     true,
		"Article":    article,
		"TinyMCEKey": os.Getenv("TINY_MCE_KEY"),
	}, "layouts/main")
}

func (h *AdminHandler) UpdateArticle(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))

	// Handle Image Upload
	imageURL := c.FormValue("current_image_url") // Default to existing image
	file, err := c.FormFile("image_file")
	if err == nil {
		// Generate unique filename
		ext := filepath.Ext(file.Filename)
		filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		path := fmt.Sprintf("./static/uploads/%s", filename)

		// Save file
		if err := c.SaveFile(file, path); err != nil {
			return c.Status(fiber.StatusInternalServerError).SendString("Error saving image: " + err.Error())
		}
		imageURL = fmt.Sprintf("/uploads/%s", filename)
	} else if url := c.FormValue("image_url"); url != "" {
		// If user provided a URL manually and didn't upload a file
		imageURL = url
	}

	article := &domain.Article{
		ID:          id,
		Title:       c.FormValue("title"),
		Slug:        c.FormValue("slug"),
		Excerpt:     c.FormValue("excerpt"),
		Category:    c.FormValue("category"),
		ImageURL:    imageURL,
		Content:     c.FormValue("content"),
		TitleShort:  c.FormValue("title_short"),
		IsPublished: c.FormValue("is_published") == "on",
	}

	err = h.service.UpdateArticle(article)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error updating article: " + err.Error())
	}

	return c.Redirect("/admin/articles")
}

func (h *AdminHandler) DeleteArticle(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.DeleteArticle(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error deleting article")
	}
	return c.SendString("") // Remove row from DOM
}

// --- Image Management ---

func (h *AdminHandler) ShowImagesPage(c *fiber.Ctx) error {
	files, err := ioutil.ReadDir("./static/uploads")
	if err != nil {
		// Create directory if not exists
		os.MkdirAll("./static/uploads", 0755)
		files, _ = ioutil.ReadDir("./static/uploads")
	}

	// Sort files by modification time (newest first)
	sort.Slice(files, func(i, j int) bool {
		return files[i].ModTime().After(files[j].ModTime())
	})

	var images []string
	for _, file := range files {
		if !file.IsDir() {
			images = append(images, file.Name())
		}
	}

	return c.Render("admin_images", fiber.Map{
		"title":      "Manage Images",
		"Images":     images,
		"IsLoggedIn": c.Locals("IsLoggedIn"),
		"IsAdmin":    c.Locals("IsAdmin"),
		"ActivePage": "admin",
	}, "layouts/main")
}

func (h *AdminHandler) GetImagesJSON(c *fiber.Ctx) error {
	files, err := ioutil.ReadDir("./static/uploads")
	if err != nil {
		return c.JSON([]string{})
	}

	// Sort files by modification time (newest first)
	sort.Slice(files, func(i, j int) bool {
		return files[i].ModTime().After(files[j].ModTime())
	})

	var images []string
	for _, file := range files {
		if !file.IsDir() {
			images = append(images, file.Name())
		}
	}
	return c.JSON(images)
}

func (h *AdminHandler) UploadImage(c *fiber.Ctx) error {
	file, err := c.FormFile("image_file")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).SendString("No file uploaded")
	}

	// Generate unique filename
	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)
	path := fmt.Sprintf("./static/uploads/%s", filename)

	// Save file
	if err := c.SaveFile(file, path); err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error saving image: " + err.Error())
	}

	return c.Redirect("/admin/images")
}

func (h *AdminHandler) DeleteImage(c *fiber.Ctx) error {
	filename := c.Params("filename")
	path := fmt.Sprintf("./static/uploads/%s", filename)

	err := os.Remove(path)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error deleting image")
	}

	return c.SendString("") // Remove element from DOM
}
