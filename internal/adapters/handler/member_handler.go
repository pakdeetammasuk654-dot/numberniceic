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

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type MemberHandler struct {
	service          *service.MemberService
	savedNameService *service.SavedNameService
	klakiniCache     *cache.KlakiniCache
	numberPairCache  *cache.NumberPairCache
	store            *session.Store
}

func NewMemberHandler(service *service.MemberService, savedNameService *service.SavedNameService, klakiniCache *cache.KlakiniCache, numberPairCache *cache.NumberPairCache, store *session.Store) *MemberHandler {
	return &MemberHandler{
		service:          service,
		savedNameService: savedNameService,
		klakiniCache:     klakiniCache,
		numberPairCache:  numberPairCache,
		store:            store,
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

	return templ_render.Render(c, layout.Main(
		"ลงทะเบียน",
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"register",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Register(),
	))
}

// HandleRegister handles the form submission from the registration page.
func (h *MemberHandler) HandleRegister(c *fiber.Ctx) error {
	username := strings.TrimSpace(c.FormValue("username"))
	password := c.FormValue("password")
	email := strings.TrimSpace(c.FormValue("email"))
	tel := strings.TrimSpace(c.FormValue("tel"))

	sess, _ := h.store.Get(c)

	if username == "" || password == "" {
		sess.Set("toast_error", "กรุณากรอกชื่อผู้ใช้และรหัสผ่าน")
		sess.Save()
		return c.Redirect("/register")
	}

	err := h.service.Register(username, password, email, tel)
	if err != nil {
		log.Printf("Register Error: %v", err) // Log the error
		sess.Set("toast_error", "เกิดข้อผิดพลาดในการลงทะเบียน: "+err.Error())
		sess.Save()
		return c.Redirect("/register")
	}

	sess.Set("toast_success", "ลงทะเบียนสำเร็จ! กรุณาเข้าสู่ระบบ")
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

	return templ_render.Render(c, layout.Main(
		"เข้าสู่ระบบ",
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"login",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Login(),
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
		log.Printf("Login Error: %v", err) // Log the error
		sess.Set("toast_error", "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง")
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
	sess, _ := h.store.Get(c)
	memberID := sess.Get("member_id").(int)

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

	return templ_render.Render(c, layout.Main(
		"แดชบอร์ด",
		c.Locals("IsLoggedIn").(bool),
		c.Locals("IsAdmin").(bool),
		c.Locals("IsVIP").(bool),
		"dashboard",
		getLocStr("toast_success"),
		getLocStr("toast_error"),
		pages.Dashboard(member.Username, member.Email, member.Tel, displayNames),
	))
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
	displayNames := make([]domain.SavedNameDisplay, len(savedNames))
	for i, sn := range savedNames {
		satPairs := h.getPairsWithColors(sn.SatSum)
		shaPairs := h.getPairsWithColors(sn.ShaSum)

		// Calculate IsTopTier
		isTopTier := h.isAllPairsTopTier(satPairs) && h.isAllPairsTopTier(shaPairs)

		// Create DisplayNameHTML
		var displayChars []domain.DisplayChar
		for _, r := range sn.Name {
			displayChars = append(displayChars, domain.DisplayChar{Char: string(r), IsBad: false})
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
	for _, p := range pairs {
		if meaning, ok := h.numberPairCache.GetMeaning(p.Number); ok {
			switch meaning.PairType {
			case "D10", "D8", "D5":
			default:
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
