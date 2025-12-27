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
	service            *service.AdminService
	sampleCache        *cache.SampleNamesCache
	store              *session.Store
	buddhistDayService *service.BuddhistDayService
	walletColorService *service.WalletColorService
}

func NewAdminHandler(service *service.AdminService, sampleCache *cache.SampleNamesCache, store *session.Store, buddhistDayService *service.BuddhistDayService, walletColorService *service.WalletColorService) *AdminHandler {
	return &AdminHandler{service: service, sampleCache: sampleCache, store: store, buddhistDayService: buddhistDayService, walletColorService: walletColorService}
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

// --- Buddhist Day Management ---

func (h *AdminHandler) ShowBuddhistDaysPage(c *fiber.Ctx) error {
	days, err := h.buddhistDayService.GetAllDays()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading buddhist days")
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
			Title:  "Manage Buddhist Days",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.BuddhistDays(days),
	))
}

func (h *AdminHandler) AddBuddhistDay(c *fiber.Ctx) error {
	dateStr := c.FormValue("date")
	err := h.buddhistDayService.AddDay(dateStr)
	if err != nil {
		// Handle error (e.g., duplicate date)
		sess, _ := h.store.Get(c)
		sess.Set("toast_error", "Error adding date: "+err.Error())
		sess.Save()
		return c.Redirect("/admin/buddhist-days")
	}
	return c.Redirect("/admin/buddhist-days")
}

func (h *AdminHandler) DeleteBuddhistDay(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.buddhistDayService.DeleteDay(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error deleting day")
	}
	return c.SendString("") // Remove row from DOM
}

// --- API for Android App ---

func (h *AdminHandler) GetBuddhistDaysJSON(c *fiber.Ctx) error {
	days, err := h.buddhistDayService.GetAllDays()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Error loading buddhist days",
		})
	}
	return c.JSON(days)
}

func (h *AdminHandler) GetUpcomingBuddhistDayJSON(c *fiber.Ctx) error {
	days, err := h.buddhistDayService.GetUpcomingDays(1)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Error loading upcoming buddhist day",
		})
	}
	if len(days) == 0 {
		return c.JSON(fiber.Map{
			"message": "No upcoming buddhist days found",
		})
	}
	return c.JSON(days[0])
}

func (h *AdminHandler) CheckIsBuddhistDayJSON(c *fiber.Ctx) error {
	dateStr := c.Query("date")
	var date time.Time
	var err error

	if dateStr == "" {
		date = time.Now().Truncate(24 * time.Hour)
	} else {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid date format. Use YYYY-MM-DD",
			})
		}
	}

	isBuddhistDay, err := h.buddhistDayService.IsBuddhistDay(date)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Error checking buddhist day",
		})
	}

	return c.JSON(fiber.Map{
		"date":            date.Format("2006-01-02"),
		"is_buddhist_day": isBuddhistDay,
	})
}

// --- API Docs ---
func (h *AdminHandler) ShowAPIDocsPage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "API Documentation",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.APIDocs(),
	))
}

// --- Wallet Color Management ---

func (h *AdminHandler) ShowWalletColorsPage(c *fiber.Ctx) error {
	colors, err := h.walletColorService.GetAll()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading wallet colors")
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
			Title:  "Manage Wallet Colors",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.WalletColors(colors),
	))
}

func (h *AdminHandler) ShowEditWalletColorRow(c *fiber.Ctx) error {
	dayOfWeek, _ := strconv.Atoi(c.Params("day"))
	color, err := h.walletColorService.GetByDay(dayOfWeek)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading color")
	}
	return templ_render.Render(c, admin.WalletColorEditRow(*color))
}

func (h *AdminHandler) CancelEditWalletColorRow(c *fiber.Ctx) error {
	dayOfWeek, _ := strconv.Atoi(c.Params("day"))
	color, err := h.walletColorService.GetByDay(dayOfWeek)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading color")
	}
	return templ_render.Render(c, admin.WalletColorRow(*color))
}

func (h *AdminHandler) UpdateWalletColor(c *fiber.Ctx) error {
	dayOfWeek, _ := strconv.Atoi(c.Params("day"))
	colorName := c.FormValue("color_name")
	colorHex := c.FormValue("color_hex")
	description := c.FormValue("description")

	color := &domain.WalletColor{
		DayOfWeek:   dayOfWeek,
		ColorName:   colorName,
		ColorHex:    colorHex,
		Description: description,
	}

	err := h.walletColorService.Update(color)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error updating color")
	}

	// Return the updated row (read-only view)
	updatedColor, _ := h.walletColorService.GetByDay(dayOfWeek)
	c.Set("HX-Trigger", "show-toast-success")
	return templ_render.Render(c, admin.WalletColorRow(*updatedColor))
}

// --- Customer Color Report ---

func (h *AdminHandler) ShowCustomerColorReportPage(c *fiber.Ctx) error {
	username := c.Query("username")
	var member *domain.Member

	if username != "" {
		member, _ = h.service.GetMemberByUsername(username)
	}

	recentAssignments, _ := h.service.GetMembersWithAssignedColors()

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Customer Color Report",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		admin.CustomerColorReport(member, username, recentAssignments),
	))
}

func (h *AdminHandler) AssignCustomerColors(c *fiber.Ctx) error {
	memberID, _ := strconv.Atoi(c.FormValue("member_id"))
	username := c.FormValue("username")

	// Collect 5 colors
	colors := make([]string, 5)
	for i := 1; i <= 5; i++ {
		cHex := c.FormValue(fmt.Sprintf("color_%d", i))
		colors[i-1] = cHex
	}

	colorsStr := strings.Join(colors, ",")

	err := h.service.UpdateAssignedColors(memberID, colorsStr)

	sess, _ := h.store.Get(c)
	if err != nil {
		sess.Set("toast_error", "บันทึกสีไม่สำเร็จ: "+err.Error())
	} else {
		sess.Set("toast_success", "บันทึกสีกระเป๋าเรียบร้อยแล้ว")
	}
	sess.Save()

	return c.Redirect("/admin/customer-color-report?username=" + username)
}
