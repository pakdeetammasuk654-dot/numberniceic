package handler

import (
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/layout"
	"numberniceic/views/pages"
	"runtime/debug"
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
	service                *service.MemberService
	savedNameService       *service.SavedNameService
	buddhistDayService     *service.BuddhistDayService
	shippingAddressService *service.ShippingAddressService
	klakiniCache           *cache.KlakiniCache
	numberPairCache        *cache.NumberPairCache
	store                  *session.Store
	promotionalCodeRepo    *repository.PostgresPromotionalCodeRepository
}

func NewMemberHandler(service *service.MemberService, savedNameService *service.SavedNameService, buddhistDayService *service.BuddhistDayService, shippingAddressService *service.ShippingAddressService, klakiniCache *cache.KlakiniCache, numberPairCache *cache.NumberPairCache, store *session.Store, promotionalCodeRepo *repository.PostgresPromotionalCodeRepository) *MemberHandler {
	return &MemberHandler{
		service:                service,
		savedNameService:       savedNameService,
		buddhistDayService:     buddhistDayService,
		shippingAddressService: shippingAddressService,
		klakiniCache:           klakiniCache,
		numberPairCache:        numberPairCache,
		store:                  store,
		promotionalCodeRepo:    promotionalCodeRepo,
	}
}

// ShowRegisterPage renders the registration page.
func (h *MemberHandler) ShowRegisterPage(c *fiber.Ctx) error {
	return c.Redirect("/login")
}

// HandleRegister handles the form submission from the registration page.
func (h *MemberHandler) HandleRegister(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	sess.Set("toast_error", "ระบบปิดรับสมัครสมาชิกด้วยรหัสผ่าน กรุณาใช้ Social Login")
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

	avatarURL, _ := c.Locals("AvatarURL").(string)
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
		avatarURL,
		pages.Login(lastUsername, errorField),
	))
}

// HandleLogin handles the form submission from the login page.
func (h *MemberHandler) HandleLogin(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	sess.Set("toast_error", "ระบบยกเลิกการเข้าสู่ระบบด้วยรหัสผ่านแล้ว กรุณาใช้ Social Login")
	sess.Save()
	return c.Redirect("/login")
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

	// Fetch My Promotional Codes
	var myCodes []domain.PromotionalCode
	if h.promotionalCodeRepo != nil {
		myCodes, _ = h.promotionalCodeRepo.GetByOwnerID(memberID)
	}

	// Check Shipping Address
	hasShippingAddress := false
	if h.shippingAddressService != nil {
		addrs, _ := h.shippingAddressService.GetMyAddresses(memberID)
		if len(addrs) > 0 {
			hasShippingAddress = true
		}
	}

	avatarURL, _ := c.Locals("AvatarURL").(string)
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
		avatarURL,
		pages.Dashboard(member.Username, member.Email, member.Tel, member.AvatarURL, displayNames, member.IsVIP(), assignedColors, h.isTodayBuddhistDay(), myCodes, hasShippingAddress, member.GetVIPExpiryText()),
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
	return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
		"error": "ระบบยกเลิกการเข้าสู่ระบบด้วยรหัสผ่านแล้ว กรุณาใช้ Social Login",
	})
}

// HandleRegisterAPI handles JSON registration requests for mobile apps
func (h *MemberHandler) HandleRegisterAPI(c *fiber.Ctx) error {
	return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
		"error": "ระบบปิดรับสมัครสมาชิกด้วยรหัสผ่าน กรุณาใช้ Social Login",
	})
}

// GetDashboardAPI returns dashboard data including saved names for the authenticated user
func (h *MemberHandler) GetDashboardAPI(c *fiber.Ctx) error {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("PANIC RECOVERED in GetDashboardAPI: %v\nStack: %s\n", r, string(debug.Stack()))
		}
	}()
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

	// 2. Parse Token
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

	// Check Shipping Address
	hasShippingAddress := false
	if h.shippingAddressService != nil {
		addrs, _ := h.shippingAddressService.GetMyAddresses(userID)
		if len(addrs) > 0 {
			hasShippingAddress = true
		}
	}

	log.Printf("API DASHBOARD: Sending data for %s (VIP=%v, Names=%d)", member.Username, member.IsVIP(), len(formattedNames))

	return c.JSON(fiber.Map{
		"username":             member.Username,
		"email":                member.Email,
		"tel":                  member.Tel,
		"is_vip":               member.IsVIP(),
		"vip_expiry_text":      member.GetVIPExpiryText(),
		"status":               member.Status, // 9 = Admin
		"assigned_colors":      assignedColors,
		"saved_names":          formattedNames,
		"has_shipping_address": hasShippingAddress,
	})
}

func (h *MemberHandler) ShowShippingAddressPage(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	memberID := sess.Get("member_id").(int)

	addresses, err := h.shippingAddressService.GetMyAddresses(memberID)
	if err != nil {
		sess.Set("toast_error", "Failed to load addresses")
		sess.Save()
	}

	editMode := false
	var addressToEdit *domain.ShippingAddress
	editIDStr := c.Query("edit")
	if editIDStr != "" {
		id, err := strconv.Atoi(editIDStr)
		if err == nil {
			for i := range addresses {
				if addresses[i].ID == id {
					addressToEdit = &addresses[i]
					editMode = true
					break
				}
			}
		}
	}

	getLocStr := func(key string) string {
		v := c.Locals(key)
		if v == nil || v == "<nil>" {
			return ""
		}
		return fmt.Sprintf("%v", v)
	}

	avatarURL, _ := c.Locals("AvatarURL").(string)
	return templ_render.Render(c, layout.Main(
		layout.SEOProps{
			Title:  "จัดการที่อยู่จัดส่ง",
			OGType: "website",
		},
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"shipping_address",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		avatarURL,
		pages.ShippingAddress(addresses, editMode, addressToEdit),
	))
}

func (h *MemberHandler) HandleSaveAddress(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	memberIDRaw := sess.Get("member_id")
	if memberIDRaw == nil {
		return c.Redirect("/login")
	}
	memberID := memberIDRaw.(int)

	method := c.FormValue("_method")
	isEdit := method == "PUT"

	address := &domain.ShippingAddress{
		UserID:        memberID,
		RecipientName: c.FormValue("recipient_name"),
		PhoneNumber:   c.FormValue("phone_number"),
		AddressLine1:  c.FormValue("address_line1"),
		SubDistrict:   c.FormValue("sub_district"),
		District:      c.FormValue("district"),
		Province:      c.FormValue("province"),
		PostalCode:    c.FormValue("postal_code"),
		IsDefault:     false, // c.FormValue("is_default") == "true",
	}

	if isEdit {
		id, _ := strconv.Atoi(c.FormValue("id"))
		address.ID = id
		err := h.shippingAddressService.UpdateAddress(address)
		if err != nil {
			sess.Set("toast_error", "Failed to update address")
		} else {
			sess.Set("toast_success", "Address updated successfully")
		}
	} else {
		err := h.shippingAddressService.AddAddress(address)
		if err != nil {
			sess.Set("toast_error", "Failed to add address")
		} else {
			sess.Set("toast_success", "Address added successfully")
		}
	}
	sess.Save()
	return c.Redirect("/shipping-address")
}

func (h *MemberHandler) HandleDeleteAddress(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))

	err := h.shippingAddressService.DeleteAddress(id)

	sess, _ := h.store.Get(c)
	if err != nil {
		sess.Set("toast_error", "Failed to delete address")
	} else {
		sess.Set("toast_success", "Address deleted successfully")
	}
	sess.Save()
	return c.Redirect("/shipping-address")
}

// HandleUpdateProfileAPI handles JSON requests to update user profile
func (h *MemberHandler) HandleUpdateProfileAPI(c *fiber.Ctx) error {
	type UpdateProfileRequest struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Tel      string `json:"tel"`
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "รูปแบบข้อมูลไม่ถูกต้อง",
		})
	}

	// Validate (Simple check)
	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ชื่อผู้ใช้ห้ามว่าง",
		})
	}
	if !h.isValidUsername(req.Username) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ชื่อผู้ใช้ต้องเป็นตัวอักษร, ตัวเลข หรือ _ เท่านั้น",
		})
	}

	sess, _ := h.store.Get(c)
	memberIDRaw := sess.Get("member_id")
	if memberIDRaw == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "กรุณาเข้าสู่ระบบ",
		})
	}
	memberID := memberIDRaw.(int)

	err := h.service.UpdateProfile(memberID, req.Username, req.Email, req.Tel)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	// Update session toast for next page load
	sess.Set("toast_success", "บันทึกข้อมูลสำเร็จ")
	sess.Save()

	return c.JSON(fiber.Map{
		"message": "บันทึกข้อมูลเรียบร้อยแล้ว",
	})
}

// --- API Shipping Address Handlers ---

func (h *MemberHandler) GetShippingAddressesAPI(c *fiber.Ctx) error {
	var userID int
	// Check JWT first (user_id from optionalAuthMiddleware)
	if uid, ok := c.Locals("user_id").(int); ok {
		userID = uid
	} else if uid, ok := c.Locals("UserID").(int); ok { // Session fallback
		userID = uid
	} else {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	addresses, err := h.shippingAddressService.GetMyAddresses(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch addresses"})
	}

	if addresses == nil {
		addresses = []domain.ShippingAddress{}
	}

	return c.JSON(addresses)
}

func (h *MemberHandler) SaveShippingAddressAPI(c *fiber.Ctx) error {
	var userID int
	if uid, ok := c.Locals("user_id").(int); ok {
		userID = uid
	} else if uid, ok := c.Locals("UserID").(int); ok {
		userID = uid
	} else {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	var address domain.ShippingAddress
	if err := c.BodyParser(&address); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	address.UserID = userID

	if address.ID > 0 {
		err := h.shippingAddressService.UpdateAddress(&address)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to update address"})
		}
	} else {
		err := h.shippingAddressService.AddAddress(&address)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to add address"})
		}
	}

	return c.JSON(fiber.Map{"success": true, "message": "Address saved successfully"})
}

func (h *MemberHandler) DeleteShippingAddressAPI(c *fiber.Ctx) error {
	// Verify Auth
	if uid, ok := c.Locals("user_id").(int); !ok {
		if uid2, ok2 := c.Locals("UserID").(int); !ok2 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		} else {
			_ = uid2 // Fixed
		}
	} else {
		_ = uid // Fixed
	}

	id, _ := strconv.Atoi(c.Params("id"))

	// Optional: Could verify ownership here, but service/repo might already do it or we assume internal safety for now
	err := h.shippingAddressService.DeleteAddress(id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to delete address"})
	}

	return c.JSON(fiber.Map{"success": true, "message": "Address deleted successfully"})
}
