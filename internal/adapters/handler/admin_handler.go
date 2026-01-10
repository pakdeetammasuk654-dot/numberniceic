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
	service                *service.AdminService
	sampleCache            *cache.SampleNamesCache
	store                  *session.Store
	buddhistDayService     *service.BuddhistDayService
	walletColorService     *service.WalletColorService
	shippingAddressService *service.ShippingAddressService
	mobileConfigService    *service.MobileConfigService
	notificationService    *service.NotificationService
	memberService          *service.MemberService
}

func NewAdminHandler(service *service.AdminService, sampleCache *cache.SampleNamesCache, store *session.Store, buddhistDayService *service.BuddhistDayService, walletColorService *service.WalletColorService, shippingAddressService *service.ShippingAddressService, mobileConfigService *service.MobileConfigService, notificationService *service.NotificationService, memberService *service.MemberService) *AdminHandler {
	return &AdminHandler{service: service, sampleCache: sampleCache, store: store, buddhistDayService: buddhistDayService, walletColorService: walletColorService, shippingAddressService: shippingAddressService, mobileConfigService: mobileConfigService, notificationService: notificationService, memberService: memberService}
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.Dashboard(),
	))
}

func (h *AdminHandler) ShowAuspiciousNumbersPage(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	pageSize := 20

	pagedResult, err := h.service.GetSellNumbersPaged(page, pageSize)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading auspicious numbers")
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
			Title:  "เบอร์มงคล",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.AuspiciousNumbers(pagedResult),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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

func (h *AdminHandler) HandleViewUserAddress(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	c.Set("Content-Type", "text/html; charset=utf-8")

	addresses, err := h.shippingAddressService.GetMyAddresses(id)
	if err != nil {
		return c.SendString(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>User Address</title><style>body{font-family:'Kanit',sans-serif;padding:20px;background:#f8f9fa;}</style></head><body><h3 style='text-align:center;color:#666;'>เกิดข้อผิดพลาดในการโหลดที่อยู่</h3><div style="text-align:center;margin-top:20px;"><button onclick="window.close()" style="padding:10px 20px;cursor:pointer;">ปิดหน้าต่าง</button></div></body></html>`)
	}

	if len(addresses) == 0 {
		return c.SendString(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>User Address</title><style>body{font-family:'Kanit',sans-serif;padding:20px;background:#f8f9fa;}</style></head><body><h3 style='text-align:center;color:#666;'>ไม่พบข้อมูลที่อยู่จัดส่งสำหรับสมาชิกรายนี้</h3><div style="text-align:center;margin-top:20px;"><button onclick="window.close()" style="padding:10px 20px;cursor:pointer;">ปิดหน้าต่าง</button></div></body></html>`)
	}

	html := `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>User Address</title><style>body{font-family:'Kanit',sans-serif;padding:20px;background:#f8f9fa;}.card{background:white;padding:20px;border-radius:10px;box-shadow:0 4px 6px rgba(0,0,0,0.1);margin-bottom:15px;}.default-badge{background:#2da44e;color:white;padding:2px 8px;border-radius:12px;font-size:0.8rem;float:right;}</style></head><body><h2>รายการที่อยู่จัดส่ง</h2>`

	for _, addr := range addresses {
		// badge := ""
		// if addr.IsDefault {
		// 	badge = `<span class="default-badge">Default</span>`
		// }

		html += fmt.Sprintf(`<div class="card">
			<h3 style="margin:0 0 10px 0;">%s</h3>
			<p style="margin:0 0 5px 0;"><strong>Tel:</strong> %s</p>
			<p style="color:#555;">%s<br>%s, %s<br>%s %s</p>
		</div>`, addr.RecipientName, addr.PhoneNumber, addr.AddressLine1, addr.SubDistrict, addr.District, addr.Province, addr.PostalCode)
	}
	html += `<div style="text-align:center;margin-top:20px;"><button onclick="window.close()" style="padding:10px 20px;cursor:pointer;">Close</button></div></body></html>`

	c.Set("Content-Type", "text/html")
	return c.SendString(html)
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
	page, _ := strconv.Atoi(c.Query("page", "1"))
	if page < 1 {
		page = 1
	}
	pageSize := 20

	days, total, err := h.buddhistDayService.GetPaginatedDays(page, pageSize)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading buddhist days")
	}

	totalPages := (total + pageSize - 1) / pageSize

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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.BuddhistDays(days, page, totalPages),
	))
}

func (h *AdminHandler) AddBuddhistDay(c *fiber.Ctx) error {
	dateStr := c.FormValue("date")
	title := c.FormValue("title")
	message := c.FormValue("message")

	err := h.buddhistDayService.AddDay(dateStr, title, message)
	if err != nil {
		sess, _ := h.store.Get(c)
		sess.Set("toast_error", "Error adding date: "+err.Error())
		sess.Save()
		return c.Redirect("/admin/buddhist-days")
	}
	return c.Redirect("/admin/buddhist-days")
}

func (h *AdminHandler) UpdateBuddhistDay(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	title := c.FormValue("title")
	message := c.FormValue("message")

	err := h.buddhistDayService.UpdateDay(id, title, message)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// For HTMX inline editing, we might want to return the updated record or just success
	c.Set("HX-Trigger", "show-toast")
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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

	// HX-Trigger to update toast or other parts if needed
	c.Set("HX-Trigger", "show-toast")

	// Return the View Row
	updatedColor, _ := h.walletColorService.GetByDay(dayOfWeek)
	return templ_render.Render(c, admin.WalletColorRow(*updatedColor))
}

// --- Product Management ---

func (h *AdminHandler) ShowProductsPage(c *fiber.Ctx) error {
	products, err := h.service.GetAllProducts()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading products")
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
			Title:  "Manage Products",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.Products(products),
	))
}

func (h *AdminHandler) ShowCreateProductPage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Create Product",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.ProductForm(false, nil),
	))
}

func (h *AdminHandler) CreateProduct(c *fiber.Ctx) error {
	// Handle Image Upload
	imagePath := ""
	file, err := c.FormFile("image_file")
	if err == nil {
		ext := filepath.Ext(file.Filename)
		filename := fmt.Sprintf("prod_%s%s", uuid.New().String(), ext)
		path := fmt.Sprintf("./static/uploads/products/%s", filename)
		// Ensure dir exists
		os.MkdirAll("./static/uploads/products", 0755)

		if err := c.SaveFile(file, path); err != nil {
			return c.Status(fiber.StatusInternalServerError).SendString("Error saving image: " + err.Error())
		}
		imagePath = fmt.Sprintf("/uploads/products/%s", filename)
	}

	price, _ := strconv.Atoi(c.FormValue("price"))

	product := &domain.Product{
		Code:        c.FormValue("code"),
		Name:        c.FormValue("name"),
		Description: c.FormValue("description"),
		Price:       price,
		ImagePath:   imagePath,
		IconType:    c.FormValue("icon_type"),
		ImageColor1: c.FormValue("image_color_1"),
		ImageColor2: c.FormValue("image_color_2"),
		IsActive:    c.FormValue("is_active") == "on",
	}

	err = h.service.CreateProduct(product)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error creating product: " + err.Error())
	}

	return c.Redirect("/admin/products")
}

func (h *AdminHandler) ShowEditProductPage(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	product, err := h.service.GetProductByID(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading product")
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
			Title:  "Edit Product",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.ProductForm(true, product),
	))
}

func (h *AdminHandler) UpdateProduct(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))

	// Handle Image Upload
	imagePath := c.FormValue("current_image_path")
	file, err := c.FormFile("image_file")
	if err == nil {
		ext := filepath.Ext(file.Filename)
		filename := fmt.Sprintf("prod_%s%s", uuid.New().String(), ext)
		path := fmt.Sprintf("./static/uploads/products/%s", filename)
		os.MkdirAll("./static/uploads/products", 0755)

		if err := c.SaveFile(file, path); err != nil {
			return c.Status(fiber.StatusInternalServerError).SendString("Error saving image: " + err.Error())
		}
		imagePath = fmt.Sprintf("/uploads/products/%s", filename)
	}

	price, _ := strconv.Atoi(c.FormValue("price"))

	product := &domain.Product{
		ID:          id,
		Code:        c.FormValue("code"),
		Name:        c.FormValue("name"),
		Description: c.FormValue("description"),
		Price:       price,
		ImagePath:   imagePath,
		IconType:    c.FormValue("icon_type"),
		ImageColor1: c.FormValue("image_color_1"),
		ImageColor2: c.FormValue("image_color_2"),
		IsActive:    c.FormValue("is_active") == "on",
	}

	err = h.service.UpdateProduct(product)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error updating product: " + err.Error())
	}

	return c.Redirect("/admin/products")
}

func (h *AdminHandler) DeleteProduct(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.DeleteProduct(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error deleting product")
	}
	return c.SendString("") // Remove row from DOM
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
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
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

// --- Order Management ---

func (h *AdminHandler) HandleManageOrders(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	if page < 1 {
		page = 1
	}
	limit := 20
	search := c.Query("q", "")

	orders, total, err := h.service.GetOrdersPaginated(page, limit, search)
	if err != nil {
		return c.Status(500).SendString("Failed to fetch orders: " + err.Error())
	}

	totalPages := int(total / int64(limit))
	if total%int64(limit) > 0 {
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
			Title:  "จัดการคำสั่งซื้อ | Admin Dashboard",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.Orders(orders, page, totalPages, search),
	))
}

func (h *AdminHandler) HandleDeleteOrder(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(400).SendString("Invalid ID")
	}

	err = h.service.DeleteOrder(id)
	if err != nil {
		return c.Status(500).SendString("Failed to delete order")
	}

	return c.SendStatus(200) // HTMX expects 200 OK to swap content (empty in this case with hx-swap="outerHTML")
}

// --- Mobile Config Management ---

func (h *AdminHandler) ShowMobileConfigPage(c *fiber.Ctx) error {
	config, err := h.mobileConfigService.GetWelcomeMessage()
	if err != nil {
		// If error (or empty table), return empty or default
		// But migration puts one.
		// return c.Status(fiber.StatusInternalServerError).SendString("Error loading mobile config")
		// Just create a default placeholder
		config = &domain.MobileWelcomeConfig{
			Title:     "Welcome",
			Body:      "Welcome to our app",
			IsActive:  true,
			Version:   1,
			CreatedAt: time.Now(),
		}
	}
	if config == nil {
		config = &domain.MobileWelcomeConfig{
			Title:     "ยินดีต้อนรับ!",
			Body:      "ขอต้อนรับสู่ NumberNiceIC...",
			IsActive:  true,
			Version:   1,
			CreatedAt: time.Now(),
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
			Title:  "Mobile App Config",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.MobileConfig(config),
	))
}

func (h *AdminHandler) UpdateMobileConfig(c *fiber.Ctx) error {
	title := c.FormValue("title")
	body := c.FormValue("body")
	isActive := c.FormValue("is_active") == "on"

	err := h.mobileConfigService.UpdateWelcomeMessage(title, body, isActive)
	if err != nil {
		sess, _ := h.store.Get(c)
		sess.Set("toast_error", "Error updating config: "+err.Error())
		sess.Save()
		return c.Redirect("/admin/welcome-message")
	}

	sess, _ := h.store.Get(c)
	sess.Set("toast_success", "Mobile config updated successfully")
	sess.Save()
	return c.Redirect("/admin/welcome-message")
}

func (h *AdminHandler) GetWelcomeMessageAPI(c *fiber.Ctx) error {
	config, err := h.mobileConfigService.GetWelcomeMessage()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if config == nil {
		return c.Status(404).JSON(fiber.Map{"error": "Config not found"})
	}
	return c.JSON(config)
}

// --- Notification Management ---

func (h *AdminHandler) ShowNotificationPage(c *fiber.Ctx) error {
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

	history, err := h.notificationService.GetNotificationHistory(50)
	if err != nil {
		history = []domain.AdminNotificationHistory{}
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "Send Notification",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.SendNotification(users, history),
	))
}

func (h *AdminHandler) SendNotification(c *fiber.Ctx) error {
	userID, _ := strconv.Atoi(c.FormValue("user_id"))
	title := c.FormValue("title")
	message := c.FormValue("message")

	if userID == 0 || title == "" || message == "" {
		sess, _ := h.store.Get(c)
		sess.Set("toast_error", "Missing required fields")
		sess.Save()
		return c.Redirect("/admin/notification")
	}

	err := h.notificationService.SendNotification(userID, title, message)
	if err != nil {
		sess, _ := h.store.Get(c)
		sess.Set("toast_error", "Failed to send notification: "+err.Error())
		sess.Save()
		return c.Redirect("/admin/notification")
	}

	sess, _ := h.store.Get(c)
	sess.Set("toast_success", "Notification sent successfully!")
	sess.Save()
	return c.Redirect("/admin/notification")
}

// --- Notification API for Mobile ---

func (h *AdminHandler) GetUserNotificationsAPI(c *fiber.Ctx) error {
	userID, ok := c.Locals("UserID").(int)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	notifs, err := h.notificationService.GetUserNotifications(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch notifications"})
	}
	if notifs == nil {
		notifs = []domain.UserNotification{}
	}
	return c.JSON(notifs)
}

func (h *AdminHandler) GetUnreadCountAPI(c *fiber.Ctx) error {
	userID, ok := c.Locals("UserID").(int)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	count, err := h.notificationService.GetUnreadCount(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to count unread"})
	}
	return c.JSON(fiber.Map{"count": count})
}

func (h *AdminHandler) MarkNotificationReadAPI(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	err := h.notificationService.MarkAsRead(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to update"})
	}
	return c.JSON(fiber.Map{"success": true})
}

// --- VIP Codes Management ---

func (h *AdminHandler) ShowVIPCodesPage(c *fiber.Ctx) error {
	codes, err := h.service.GetAllPromotionalCodes()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading codes")
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
			Title:  "Manage VIP Codes",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		true,
		"admin",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		func() string { s, _ := c.Locals("AvatarURL").(string); return s }(),
		admin.VIPCodes(codes),
	))
}

func (h *AdminHandler) HandleGenerateVIPCode(c *fiber.Ctx) error {
	// Generate Random Code
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	seed := time.Now().UnixNano()
	code := "VIP-"
	for i := 0; i < 8; i++ {
		code += string(charset[seed%int64(len(charset))])
		seed = seed / int64(len(charset))
	}

	err := h.service.GenerateVIPCode(code)
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "Failed to generate code"}`)
		return c.SendStatus(fiber.StatusInternalServerError)
	}

	c.Set("HX-Trigger", `{"show-toast-success": "Generated Code: `+code+`"}`)

	// Fetch latest to get ID
	codes, _ := h.service.GetAllPromotionalCodes()
	var newCode domain.PromotionalCode
	if len(codes) > 0 {
		newCode = codes[0] // Assuming sorted by DESC
	} else {
		newCode = domain.PromotionalCode{Code: code}
	}

	return templ_render.Render(c, admin.VIPCodeRow(newCode))
}

func (h *AdminHandler) HandleBlockUserByVIPCode(c *fiber.Ctx) error {
	code := c.Params("code")
	err := h.service.SetUserStatusByVIPCode(code, -1) // Block
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "`+err.Error()+`"}`)
		return c.SendStatus(fiber.StatusBadRequest)
	}
	return h.refreshVIPCodeRow(c, code, "User blocked successfully")
}

func (h *AdminHandler) HandleUnblockUserByVIPCode(c *fiber.Ctx) error {
	code := c.Params("code")
	// Restore to VIP (2) because they used a VIP code
	err := h.service.SetUserStatusByVIPCode(code, 2)
	if err != nil {
		c.Set("HX-Trigger", `{"show-toast-error": "`+err.Error()+`"}`)
		return c.SendStatus(fiber.StatusBadRequest)
	}
	return h.refreshVIPCodeRow(c, code, "User restored successfully")
}

func (h *AdminHandler) refreshVIPCodeRow(c *fiber.Ctx, code string, successMsg string) error {
	codes, err := h.service.GetAllPromotionalCodes()
	if err != nil {
		return c.SendStatus(fiber.StatusInternalServerError)
	}

	var updatedCode domain.PromotionalCode
	for _, pc := range codes {
		if pc.Code == code {
			updatedCode = pc
			break
		}
	}

	c.Set("HX-Trigger", `{"show-toast-success": "`+successMsg+`"}`)
	return templ_render.Render(c, admin.VIPCodeRow(updatedCode))
}

// --- Notification Management ---

func (h *AdminHandler) ShowSendNotificationPage(c *fiber.Ctx) error {
	members, err := h.service.GetAllMembers()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading members")
	}

	success := c.Query("success")
	errorMsg := c.Query("error")

	avatarURL, _ := c.Locals("AvatarURL").(string)
	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "ส่งการแจ้งเตือน",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		false, // hasShippingAddress
		avatarURL,
		admin.SendNotification(members, success, errorMsg),
	))
}

func (h *AdminHandler) HandleSendNotification(c *fiber.Ctx) error {
	title := c.FormValue("title")
	message := c.FormValue("message")
	broadcast := c.FormValue("broadcast") == "true"
	userIDStr := c.FormValue("user_id")

	if title == "" || message == "" {
		return c.Redirect("/admin/send-notification?error=กรุณากรอกข้อมูลให้ครบถ้วน")
	}

	var err error
	if broadcast {
		// Send to all users
		err = h.memberService.CreateBroadcastNotification(title, message)
		if err != nil {
			return c.Redirect("/admin/send-notification?error=" + err.Error())
		}
		return c.Redirect("/admin/send-notification?success=ส่งการแจ้งเตือนให้ทุกคนเรียบร้อยแล้ว")
	} else {
		// Send to specific user
		userID, parseErr := strconv.Atoi(userIDStr)
		if parseErr != nil || userID == 0 {
			return c.Redirect("/admin/send-notification?error=กรุณาเลือกผู้ใช้งาน")
		}

		err = h.memberService.CreateUserNotification(userID, title, message)
		if err != nil {
			return c.Redirect("/admin/send-notification?error=" + err.Error())
		}
		return c.Redirect("/admin/send-notification?success=ส่งการแจ้งเตือนเรียบร้อยแล้ว")
	}
}
