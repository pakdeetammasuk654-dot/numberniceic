package handler

import (
	"fmt"
	"numberniceic/internal/core/service"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
	"github.com/gorilla/sessions"
	"github.com/markbates/goth"
	"github.com/markbates/goth/gothic"
	"github.com/markbates/goth/providers/facebook"
	"github.com/markbates/goth/providers/google"
	"github.com/markbates/goth/providers/line"
	"github.com/shareed2k/goth_fiber"
)

type AuthHandler struct {
	memberService *service.MemberService
	store         *session.Store
}

func NewAuthHandler(memberService *service.MemberService, store *session.Store) *AuthHandler {
	// Initialize Goth Providers
	// Use environment variables for keys
	baseURL := os.Getenv("BASE_URL")
	if baseURL == "" {
		baseURL = "http://localhost:3000"
	}

	goth.UseProviders(
		facebook.New(os.Getenv("FACEBOOK_KEY"), os.Getenv("FACEBOOK_SECRET"), baseURL+"/auth/facebook/callback"),
		google.New(os.Getenv("GOOGLE_KEY"), os.Getenv("GOOGLE_SECRET"), baseURL+"/auth/google/callback"),
		line.New(os.Getenv("LINE_KEY"), os.Getenv("LINE_SECRET"), baseURL+"/auth/line/callback", "profile", "openid", "email"),
	)

	// FIX: Initialize gothic.Store to handle state cookie correctly on localhost
	// Use a secure key in production!
	key := "s3cr3t-k3y-f0r-num63rn1c31c-m0b1l3-@pp"
	cookieStore := sessions.NewCookieStore([]byte(key))
	cookieStore.Options.HttpOnly = true
	cookieStore.Options.Secure = false // Set to true in production with HTTPS
	gothic.Store = cookieStore

	return &AuthHandler{
		memberService: memberService,
		store:         store,
	}
}

// Redirect to provider
func (h *AuthHandler) Login(c *fiber.Ctx) error {
	return goth_fiber.BeginAuthHandler(c)
}

// Handle callback from provider
// Handle callback from provider
func (h *AuthHandler) Callback(c *fiber.Ctx) error {
	fmt.Println("DEBUG: AuthHandler.Callback triggered")
	user, err := goth_fiber.CompleteUserAuth(c)
	if err != nil {
		fmt.Printf("DEBUG: goth_fiber.CompleteUserAuth error: %v\n", err)
		return c.Redirect("/login?error=" + err.Error())
	}
	fmt.Printf("DEBUG: Auth success from provider. User: %+v, AvatarURL: %s\n", user, user.AvatarURL)

	// Handle the login/registration logic
	member, err := h.memberService.HandleSocialLogin(user.Provider, user.UserID, user.Email, user.Name, user.AvatarURL)
	if err != nil {
		fmt.Printf("DEBUG: HandleSocialLogin error: %v\n", err)
		return c.Redirect("/login?error=" + err.Error())
	}
	fmt.Printf("DEBUG: Member logged in/registered: ID=%d, Username=%s\n", member.ID, member.Username)

	// Create Session
	sess, err := h.store.Get(c)
	if err != nil {
		fmt.Printf("DEBUG: Session store Get error: %v\n", err)
		return err
	}
	sess.Set("member_id", member.ID)
	sess.Set("is_admin", member.Status == 9)
	sess.Set("is_vip", member.IsVIP())
	sess.Set("toast_success", fmt.Sprintf("เข้าสู่ระบบเรียบร้อยแล้ว ยินดีต้อนรับคุณ %s", member.Username))

	if err := sess.Save(); err != nil {
		fmt.Printf("DEBUG: Session Save error: %v\n", err)
		return err
	}
	fmt.Println("DEBUG: Session saved successfully. Redirecting to /dashboard")

	return c.Redirect("/dashboard")
}
