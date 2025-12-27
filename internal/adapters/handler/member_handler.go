package handler

import (
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/layout"
	"numberniceic/views/pages"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
	"github.com/golang-jwt/jwt/v5"
)

const jwtSecret = "s3cr3t-k3y-f0r-num63rn1c31c-m0b1l3-@pp" // TODO: Use env variable in production

type MemberHandler struct {
	service            *service.MemberService
	savedNameService   *service.SavedNameService
	buddhistDayService *service.BuddhistDayService
	klakiniCache       *cache.KlakiniCache
	numberPairCache    *cache.NumberPairCache
	store              *session.Store
}

func NewMemberHandler(service *service.MemberService, savedNameService *service.SavedNameService, buddhistDayService *service.BuddhistDayService, klakiniCache *cache.KlakiniCache, numberPairCache *cache.NumberPairCache, store *session.Store) *MemberHandler {
	return &MemberHandler{
		service:            service,
		savedNameService:   savedNameService,
		buddhistDayService: buddhistDayService,
		klakiniCache:       klakiniCache,
		numberPairCache:    numberPairCache,
		store:              store,
	}
}

// ShowRegisterPage renders the registration page.
func (h *MemberHandler) ShowRegisterPage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	sess, _ := h.store.Get(c)
	lastUsername := ""
	lastEmail := ""
	lastTel := ""
	errorField := ""

	if v := sess.Get("reg_username"); v != nil {
		lastUsername = v.(string)
		sess.Delete("reg_username")
	}
	if v := sess.Get("reg_email"); v != nil {
		lastEmail = v.(string)
		sess.Delete("reg_email")
	}
	if v := sess.Get("reg_tel"); v != nil {
		lastTel = v.(string)
		sess.Delete("reg_tel")
	}
	if v := sess.Get("error_field"); v != nil {
		errorField = v.(string)
		sess.Delete("error_field")
	}
	sess.Save()

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:       "สมัครสมาชิก",
			Description: "สมัครสมาชิกกับ ชื่อดี.com เพื่อรับสิทธิพิเศษในการบันทึกชื่อที่คุณชื่นชอบ และเข้าถึงบทความวิเคราะห์เชิงลึก",
			Keywords:    "สมัครสมาชิก, ลงทะเบียน, ชื่อมงคล",
			Canonical:   "https://xn--b3cu8e7ah6h.com/register",
			OGType:      "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"register",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Register(lastUsername, lastEmail, lastTel, errorField),
	))
}

// HandleRegister handles the form submission from the registration page.
func (h *MemberHandler) HandleRegister(c *fiber.Ctx) error {
	username := strings.TrimSpace(c.FormValue("username"))
	password := c.FormValue("password")
	confirmPassword := c.FormValue("confirm_password")
	email := strings.TrimSpace(c.FormValue("email"))
	tel := strings.TrimSpace(c.FormValue("tel"))

	sess, _ := h.store.Get(c)

	// Helper to save form state
	saveState := func(ef string) {
		sess.Set("reg_username", username)
		sess.Set("reg_email", email)
		sess.Set("reg_tel", tel)
		sess.Set("error_field", ef)
		sess.Save()
	}

	if username == "" {
		sess.Set("toast_error", "กรุณากรอกชื่อผู้ใช้")
		saveState("username")
		return c.Redirect("/register")
	}

	if !h.isValidUsername(username) {
		sess.Set("toast_error", "Username ต้องเป็นภาษาไทย ภาษาอังกฤษ หรือตัวเลข และห้ามมีช่องว่าง")
		saveState("username")
		return c.Redirect("/register")
	}

	if password == "" {
		sess.Set("toast_error", "กรุณากรอกรหัสผ่าน")
		saveState("password")
		return c.Redirect("/register")
	}

	if password != confirmPassword {
		sess.Set("toast_error", "รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน")
		saveState("password_mismatch")
		return c.Redirect("/register")
	}

	err := h.service.Register(username, password, email, tel)
	if err != nil {
		log.Printf("Register Error: %v", err)
		sess.Set("toast_error", err.Error())

		saveState("username")
		return c.Redirect("/register")
	}

	sess.Set("toast_success", "ลงทะเบียนสำเร็จ! กรุณาเข้าสู่ระบบ")
	sess.Delete("reg_username")
	sess.Delete("reg_email")
	sess.Delete("reg_tel")
	sess.Delete("error_field")
	sess.Save()
	return c.Redirect("/login")
}

// ShowLoginPage renders the login page.
func (h *MemberHandler) ShowLoginPage(c *fiber.Ctx) error {
	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	sess, _ := h.store.Get(c)
	lastUsername := ""
	errorField := ""
	if v := sess.Get("last_username"); v != nil {
		lastUsername = v.(string)
		sess.Delete("last_username")
	}
	if v := sess.Get("error_field"); v != nil {
		errorField = v.(string)
		sess.Delete("error_field")
	}
	sess.Save()

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:       "เข้าสู่ระบบ",
			Description: "เข้าสู่ระบบ ชื่อดี.com เพื่อจัดการรายชื่อมงคลที่คุณบันทึกไว้",
			Keywords:    "เข้าสู่ระบบ, ล็อกอิน",
			Canonical:   "https://xn--b3cu8e7ah6h.com/login",
			OGType:      "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"login",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Login(lastUsername, errorField),
	))
}

// HandleLogin handles the form submission from the login page.
func (h *MemberHandler) HandleLogin(c *fiber.Ctx) error {
	username := strings.TrimSpace(c.FormValue("username"))
	password := c.FormValue("password")

	sess, _ := h.store.Get(c)

	member, err := h.service.Login(username, password)
	if err == nil {
		fmt.Printf("DEBUG: Login Success for %s. DB Status=%d. IsVIP=%v\n", member.Username, member.Status, member.IsVIP())
	}
	if err != nil {
		log.Printf("Login Error: %v", err)
		sess.Set("toast_error", err.Error())
		sess.Set("last_username", username) // Remember username
		sess.Set("error_field", "password") // Default to password if login fails
		sess.Save()
		return c.Redirect("/login")
	}

	sess.Set("member_id", member.ID)
	// Admin logic restored
	if member.Status == 9 {
		sess.Set("is_admin", true)
	} else {
		sess.Set("is_admin", false)
	}

	if member.IsVIP() {
		sess.Set("is_vip", true)
	} else {
		sess.Set("is_vip", false)
	}

	sess.Set("toast_success", "ยินดีต้อนรับกลับ, "+member.Username+"!")
	sess.Save()

	return c.Redirect("/dashboard")
}

// ShowDashboard renders the member's dashboard.
func (h *MemberHandler) ShowDashboard(c *fiber.Ctx) error {
	if h.service == nil || h.store == nil || h.savedNameService == nil {
		log.Println("ERROR: MemberHandler services or store is nil")
		return c.Status(fiber.StatusInternalServerError).SendString("Service configuration error")
	}

	sess, _ := h.store.Get(c)
	memberIDRaw := sess.Get("member_id")
	memberID, ok := memberIDRaw.(int)
	if !ok {
		return c.Redirect("/login")
	}

	member, err := h.service.GetMemberByID(memberID)
	if err != nil || member == nil {
		sess.Set("toast_error", "ไม่พบข้อมูลสมาชิก")
		sess.Save()
		return c.Redirect("/login")
	}

	savedNames, err := h.savedNameService.GetSavedNames(memberID)
	if err != nil {
		// Log error but continue rendering dashboard without saved names
	}

	displayNames := h.prepareDisplayNames(savedNames)

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	assignedColors := strings.Split(member.AssignedColors, ",")
	// Handle empty string split resulting in [""]
	if len(assignedColors) == 1 && assignedColors[0] == "" {
		assignedColors = []string{}
	}

	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:       "แดชบอร์ดส่วนตัว",
			Description: "จัดการรายชื่อมงคลที่คุณชื่นชอบและบันทึกไว้ใน ชื่อดี.com",
			OGType:      "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"dashboard",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Dashboard(member.Username, member.Email, member.Tel, displayNames, member.IsVIP(), assignedColors, h.isTodayBuddhistDay()),
	))
}

func (h *MemberHandler) isTodayBuddhistDay() bool {
	if h.buddhistDayService == nil {
		return false
	}

	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		// Fallback to Fixed Zone UTC+7 if tzdata is missing
		loc = time.FixedZone("Asia/Bangkok", 7*60*60)
	}

	// Use Thai time
	now := time.Now().In(loc)

	isDay, err := h.buddhistDayService.IsBuddhistDay(now)
	if err != nil {
		return false
	}
	return isDay
}

// HandleLogout logs the user out.
func (h *MemberHandler) HandleLogout(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)

	sess.Destroy()              // Destroy the entire session on logout
	c.ClearCookie("vip_status") // Clear VIP cookie from mock/legacy testing

	// Create a new session to store the logout message
	newSess, _ := h.store.Get(c)
	newSess.Set("toast_success", "ออกจากระบบเรียบร้อยแล้ว")
	newSess.Save()

	return c.Redirect("/login")
}

func (h *MemberHandler) prepareDisplayNames(savedNames []domain.SavedName) []domain.SavedNameDisplay {
	if h.klakiniCache == nil || h.numberPairCache == nil {
		log.Println("ERROR: Caches are nil in prepareDisplayNames")
		return nil
	}
	displayNames := make([]domain.SavedNameDisplay, len(savedNames))
	for i, sn := range savedNames {
		satPairs := h.getPairsWithColors(sn.SatSum)
		shaPairs := h.getPairsWithColors(sn.ShaSum)

		// Calculate IsTopTier
		isTopTier := h.isAllPairsTopTier(satPairs) && h.isAllPairsTopTier(shaPairs)

		// Create DisplayNameHTML
		var displayChars []domain.DisplayChar
		runes := []rune(sn.Name)
		for j := 0; j < len(runes); j++ {
			r := runes[j]
			char := string(r)
			isBad := h.klakiniCache.IsKlakini(sn.BirthDay, r)

			// Check if the next character is a combining mark
			if j+1 < len(runes) && unicode.Is(unicode.Mn, runes[j+1]) {
				combiningChar := runes[j+1]
				isCombiningBad := h.klakiniCache.IsKlakini(sn.BirthDay, combiningChar)

				// If the base is not bad, but the combining mark is
				if !isBad && isCombiningBad {
					// Add the base character as good
					displayChars = append(displayChars, domain.DisplayChar{Char: char, IsBad: false})
					// Add the combining mark as bad
					displayChars = append(displayChars, domain.DisplayChar{Char: string(combiningChar), IsBad: true})
					j++ // Skip the combining mark in the next iteration
					continue
				}
			}

			// Default behavior: add the character with its own klakini status
			displayChars = append(displayChars, domain.DisplayChar{Char: char, IsBad: isBad})
		}

		displayNames[i] = domain.SavedNameDisplay{
			SavedName:       sn,
			BirthDayThai:    service.GetThaiDay(sn.BirthDay),
			BirthDayRaw:     strings.ToUpper(sn.BirthDay),
			KlakiniChars:    h.getKlakiniChars(sn.Name, sn.BirthDay),
			SatPairs:        satPairs,
			ShaPairs:        shaPairs,
			DisplayNameHTML: displayChars,
			IsTopTier:       isTopTier,
		}
	}
	return displayNames
}

func (h *MemberHandler) isAllPairsTopTier(pairs []domain.PairInfo) bool {
	if len(pairs) == 0 {
		return false
	}
	for _, p := range pairs {
		if meaning, ok := h.numberPairCache.GetMeaning(p.Number); ok {
			if !service.IsGoodPairType(meaning.PairType) {
				return false
			}
		} else {
			return false
		}
	}
	return true
}

func (h *MemberHandler) getKlakiniChars(name, day string) []string {
	var klakiniChars []string
	for _, r := range name {
		if h.klakiniCache.IsKlakini(day, r) {
			klakiniChars = append(klakiniChars, string(r))
		}
	}
	return klakiniChars
}

func (h *MemberHandler) getPairsWithColors(sum int) []domain.PairInfo {
	if h.numberPairCache == nil {
		log.Println("ERROR: numberPairCache is nil in getPairsWithColors")
		return nil
	}
	s := strconv.Itoa(sum)
	var pairs []string
	if sum < 0 {
		// No pairs for negative sums
	} else if len(s) < 2 {
		pairs = append(pairs, "0"+s)
	} else if len(s) == 2 {
		pairs = append(pairs, s)
	} else { // len(s) > 2
		if len(s)%2 != 0 {
			for i := 0; i < len(s)-1; i++ {
				pairs = append(pairs, s[i:i+2])
			}
		} else {
			for i := 0; i < len(s); i += 2 {
				pairs = append(pairs, s[i:i+2])
			}
		}
	}

	var pairInfos []domain.PairInfo
	for _, p := range pairs {
		meaning, ok := h.numberPairCache.GetMeaning(p)
		color := "#ccc" // Default color
		if ok {
			color = meaning.Color
		}
		pairInfos = append(pairInfos, domain.PairInfo{Number: p, Color: color})
	}
	return pairInfos
}
func (h *MemberHandler) isValidUsername(username string) bool {
	if len(username) < 3 {
		return false
	}
	for _, r := range username {
		// Allow: Thai (\u0E00-\u0E7F), English (a-z, A-Z), Numbers (0-9), Underscore (_)
		if (r >= 0x0E00 && r <= 0x0E7F) ||
			(r >= 'a' && r <= 'z') ||
			(r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') ||
			r == '_' {
			continue
		}
		return false
	}
	return true
}

// HandleLoginAPI handles JSON login requests for mobile apps
func (h *MemberHandler) HandleLoginAPI(c *fiber.Ctx) error {
	type LoginRequest struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "รูปแบบข้อมูลไม่ถูกต้อง",
		})
	}

	member, err := h.service.Login(req.Username, req.Password)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง",
		})
	}

	// Fetch detailed member info to ensure including assigned_colors
	fullMember, err := h.service.GetMemberByID(member.ID)
	if err != nil {
		fullMember = member // Fallback
	}

	assignedColors := strings.Split(fullMember.AssignedColors, ",")
	if len(assignedColors) == 1 && assignedColors[0] == "" {
		assignedColors = []string{}
	}

	// Generate JWT Token
	claims := jwt.MapClaims{
		"user_id":  fullMember.ID,
		"username": fullMember.Username,
		"status":   fullMember.Status,
		"exp":      time.Now().Add(time.Hour * 72).Unix(), // Expires in 3 days
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	t, err := token.SignedString([]byte(jwtSecret))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "ไม่สามารถสร้าง Token ได้",
		})
	}

	return c.JSON(fiber.Map{
		"message":         "เข้าสู่ระบบสำเร็จ",
		"token":           t,
		"id":              fullMember.ID,
		"username":        fullMember.Username,
		"email":           fullMember.Email,
		"status":          fullMember.Status,
		"is_vip":          fullMember.IsVIP(),
		"assigned_colors": assignedColors,
	})
}

// HandleRegisterAPI handles JSON registration requests for mobile apps
func (h *MemberHandler) HandleRegisterAPI(c *fiber.Ctx) error {
	type RegisterRequest struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Email    string `json:"email"`
		Tel      string `json:"tel"`
	}

	var req RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "รูปแบบข้อมูลไม่ถูกต้อง",
		})
	}

	username := strings.TrimSpace(req.Username)
	email := strings.TrimSpace(req.Email)
	tel := strings.TrimSpace(req.Tel)

	if username == "" || req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "กรุณากรอกชื่อผู้ใช้และรหัสผ่าน",
		})
	}

	if !h.isValidUsername(username) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ชื่อผู้ใช้ต้องเป็นตัวอักษรหรือตัวเลข และห้ามมีช่องว่าง",
		})
	}

	err := h.service.Register(username, req.Password, email, tel)
	if err != nil {
		errMsg := err.Error()
		if strings.Contains(errMsg, "duplicate") || strings.Contains(errMsg, "exists") {
			errMsg = "ชื่อผู้ใช้นี้มีอยู่ในระบบแล้ว"
		}
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"error": errMsg,
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message": "สมัครสมาชิกสำเร็จ",
	})
}

// GetDashboardAPI returns dashboard data including saved names for the authenticated user
func (h *MemberHandler) GetDashboardAPI(c *fiber.Ctx) error {
	// 1. Get Token from Header
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Missing Authorization Header"})
	}
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Invalid Authorization Header Format"})
	}
	tokenString := parts[1]

	// 2. Parse and Validate Token
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(jwtSecret), nil
	})

	if err != nil || !token.Valid {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Invalid or Expired Token"})
	}

	// 3. Extract User ID
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Invalid Token Claims"})
	}

	// Handle float64 conversion typical for JSON numbers
	userIDFloat, ok := claims["user_id"].(float64)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Invalid User ID in Token"})
	}
	userID := int(userIDFloat)

	// Fetch Member Info (Refresh data)
	member, err := h.service.GetMemberByID(userID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "User not found"})
	}

	// Fetch Saved Names
	savedNames, _ := h.savedNameService.GetSavedNames(userID)

	// Prepare Display Names (Calculate summary/quality) - use the existing helper
	displayNames := h.prepareDisplayNames(savedNames)

	// Format for JSON output manually to ensure snake_case and correct types
	var formattedNames []map[string]interface{}
	for _, dn := range displayNames {
		formattedNames = append(formattedNames, map[string]interface{}{
			"id":                dn.ID,
			"name":              dn.Name,
			"birth_day_thai":    dn.BirthDayThai,
			"birth_day_raw":     dn.BirthDayRaw,
			"total_score":       dn.TotalScore,
			"is_top_tier":       dn.IsTopTier,
			"display_name_html": dn.DisplayNameHTML,
			"sat_pairs":         dn.SatPairs,
			"sha_pairs":         dn.ShaPairs,
		})
	}

	// Assigned Colors
	assignedColors := strings.Split(member.AssignedColors, ",")
	if len(assignedColors) == 1 && assignedColors[0] == "" {
		assignedColors = []string{}
	}

	log.Printf("API DASHBOARD: Sending data for %s (VIP=%v, Names=%d)", member.Username, member.IsVIP(), len(formattedNames))

	return c.JSON(fiber.Map{
		"username":        member.Username,
		"email":           member.Email,
		"tel":             member.Tel,
		"is_vip":          member.IsVIP(),
		"status":          member.Status, // 9 = Admin
		"assigned_colors": assignedColors,
		"saved_names":     formattedNames,
	})
}
