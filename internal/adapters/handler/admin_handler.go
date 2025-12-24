package handler

import (
	"fmt"
	"io/ioutil"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/layout"
	"numberniceic/views/pages/admin"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
	"github.com/google/uuid"
)

type AdminHandler struct {
	service     *service.AdminService
	sampleCache *cache.SampleNamesCache
	store       *session.Store
}

func NewAdminHandler(service *service.AdminService, sampleCache *cache.SampleNamesCache, store *session.Store) *AdminHandler {
	return &AdminHandler{service: service, sampleCache: sampleCache, store: store}
}

// --- Sample Names Management ---

func (h *AdminHandler) ShowSampleNamesPage(c *fiber.Ctx) error {
	samples, err := h.service.GetAllSampleNames()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading sample names")
	}

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Manage Sample Names",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.SampleNames(samples),
	))
}

func (h *AdminHandler) SetActiveSampleName(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.SetActiveSampleName(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error setting active sample name")
	}

	// Reload Cache
	h.sampleCache.Reload()

	// Redirect or return success
	return c.Redirect("/admin/sample-names")
}

// --- Dashboard ---
func (h *AdminHandler) ShowDashboard(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Admin Dashboard",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.Dashboard(),
	))
}

// --- User Management ---
func (h *AdminHandler) ShowUsersPage(c *fiber.Ctx) error {
	users, err := h.service.GetAllUsers()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading users")
	}

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Manage Users",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.Users(users),
	))
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
	// Render only the row partial (using Templ sub-component)
	return templ_render.Render(c, admin.UserRow(*user))
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
	page, _ := strconv.Atoi(c.Query("page", "1"))
	if page < 1 {
		page = 1
	}
	limit := 10

	articles, totalCount, err := h.service.GetArticlesPaginated(page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading articles")
	}

	totalPages := int(totalCount / int64(limit))
	if totalCount%int64(limit) > 0 {
		totalPages++
	}

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Manage Articles",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.Articles(articles, page, totalPages, page > 1, page < totalPages, page-1, page+1),
	))
}

func (h *AdminHandler) ShowCreateArticlePage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Create Article",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.ArticleForm(false, nil),
	))
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

	pinOrder, _ := strconv.Atoi(c.FormValue("pin_order"))

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
		PinOrder:    pinOrder,
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

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Edit Article",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.ArticleForm(true, article),
	))
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

	pinOrder, _ := strconv.Atoi(c.FormValue("pin_order"))

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
		PinOrder:    pinOrder,
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

func (h *AdminHandler) UpdateArticlePinOrder(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	order, _ := strconv.Atoi(c.FormValue("pin_order"))

	err := h.service.UpdateArticlePinOrder(id, order)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error updating pin order")
	}

	c.Set("HX-Trigger", "show-toast")
	return c.SendString("") // Or return updated row if needed
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

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Manage Images",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.Images(images),
	))
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

// --- Add System Name ---

func (h *AdminHandler) ShowAddNamePage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	recentNames, _ := h.service.GetLatestSystemNames(10)
	totalCount, _ := h.service.GetTotalNamesCount()

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "เพิ่มชื่อระบบ",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.AddNameForm(recentNames, totalCount),
	))
}

func (h *AdminHandler) AddSystemName(c *fiber.Ctx) error {
	name := strings.TrimSpace(c.FormValue("name"))
	if name == "" {
		if c.Get("HX-Request") == "true" {
			c.Set("HX-Trigger", `{"show-toast-error": "กรุณากรอกชื่อ"}`)
			recentNames, _ := h.service.GetLatestSystemNames(10)
			totalCount, _ := h.service.GetTotalNamesCount()
			return templ_render.Render(c, admin.RecentNamesTable(recentNames, "", "", totalCount))
		}
		return c.Status(fiber.StatusBadRequest).SendString("Name is required")
	}

	sess, _ := h.store.Get(c)

	err := h.service.AddSystemName(name)
	if err != nil {
		errorMsg := err.Error()
		lowerErr := strings.ToLower(errorMsg)
		// More robust detection for duplicate key error (PostgreSQL error 23505)
		if strings.Contains(lowerErr, "unique constraint") ||
			strings.Contains(lowerErr, "23505") ||
			strings.Contains(lowerErr, "duplicate key") {
			errorMsg = "ชื่อ '" + name + "' นี้มีอยู่ในระบบแล้ว"
		}

		if c.Get("HX-Request") == "true" {
			recentNames, _ := h.service.GetLatestSystemNames(10)
			totalCount, _ := h.service.GetTotalNamesCount()
			return templ_render.Render(c, admin.RecentNamesTable(recentNames, errorMsg, "error", totalCount))
		}
		sess.Set("toast_error", errorMsg)
		sess.Save()
		return c.Redirect("/admin/add-name")
	}

	recentNames, _ := h.service.GetLatestSystemNames(10)

	if c.Get("HX-Request") == "true" {
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "เพิ่มชื่อ '"+name+"' สำเร็จ", "success", totalCount))
	}

	sess.Set("toast_success", "เพิ่มชื่อ '"+name+"' เข้าระบบสำเร็จ")
	sess.Save()
	return c.Redirect("/admin/add-name")
}

func (h *AdminHandler) BulkUploadNames(c *fiber.Ctx) error {
	file, err := c.FormFile("bulk_file")
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "กรุณาเลือกไฟล์ที่ต้องการอัปโหลด"}`)
		recentNames, _ := h.service.GetLatestSystemNames(10)
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "", "", totalCount))
	}

	f, err := file.Open()
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "ไม่สามารถเปิดไฟล์ได้"}`)
		recentNames, _ := h.service.GetLatestSystemNames(10)
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "", "", totalCount))
	}
	defer f.Close()

	content, err := ioutil.ReadAll(f)
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "ไม่สามารถอ่านข้อมูลในไฟล์ได้"}`)
		recentNames, _ := h.service.GetLatestSystemNames(10)
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "", "", totalCount))
	}

	// Split by any whitespace (space, newline, tab, etc.)
	names := strings.Fields(string(content))
	if len(names) == 0 {
		c.Set("HX-Trigger", `{"show-toast-error": "ไม่พบรายชื่อในไฟล์"}`)
		recentNames, _ := h.service.GetLatestSystemNames(10)
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "", "", totalCount))
	}

	success, fail := h.service.AddSystemNamesBulk(names)

	msg := fmt.Sprintf("อัปโหลดสำเร็จ: %d รายชื่อ, ผิดพลาด/ซ้ำ: %d รายชื่อ", success, fail)
	recentNames, _ := h.service.GetLatestSystemNames(10)
	totalCount, _ := h.service.GetTotalNamesCount()
	return templ_render.Render(c, admin.RecentNamesTable(recentNames, msg, "success", totalCount))
}

func (h *AdminHandler) DeleteSystemName(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))

	err := h.service.DeleteSystemName(id)
	if err != nil {
		recentNames, _ := h.service.GetLatestSystemNames(10)
		totalCount, _ := h.service.GetTotalNamesCount()
		return templ_render.Render(c, admin.RecentNamesTable(recentNames, "เกิดข้อผิดพลาดในการลบ", "error", totalCount))
	}

	recentNames, _ := h.service.GetLatestSystemNames(10)
	totalCount, _ := h.service.GetTotalNamesCount()
	return templ_render.Render(c, admin.RecentNamesTable(recentNames, "ลบชื่อสำเร็จ", "success", totalCount))
}
