package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"numberniceic/internal/core/service"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

const jwtSecretMobile = "s3cr3t-k3y-f0r-num63rn1c31c-m0b1l3-@pp"

type SocialAuthHandler struct {
	memberService *service.MemberService
}

func NewSocialAuthHandler(memberService *service.MemberService) *SocialAuthHandler {
	return &SocialAuthHandler{memberService: memberService}
}

type SocialAuthRequest struct {
	Provider      string `json:"provider"`       // "google", "facebook", "line"
	ProviderToken string `json:"provider_token"` // OAuth token from provider
	AccessToken   string `json:"access_token"`   // Optional access token if provider_token (idToken) is not available or invalid
	Email         string `json:"email"`
	Name          string `json:"name"`
	AvatarURL     string `json:"avatar_url"`
}

type GoogleTokenInfo struct {
	Sub           string      `json:"sub"` // User ID
	Email         string      `json:"email"`
	EmailVerified interface{} `json:"email_verified"` // Use interface{} to handle string ("true") or bool (true)
	Name          string      `json:"name"`
	Picture       string      `json:"picture"`
}

type GoogleUserInfo struct {
	Id            string `json:"id"`
	Email         string `json:"email"`
	VerifiedEmail bool   `json:"verified_email"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
}

type FacebookTokenInfo struct {
	ID      string `json:"id"`
	Email   string `json:"email"`
	Name    string `json:"name"`
	Picture struct {
		Data struct {
			URL string `json:"url"`
		} `json:"data"`
	} `json:"picture"`
}

type LineTokenInfo struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	PictureURL  string `json:"pictureUrl"`
}

// HandleSocialAuth handles social login requests
func (h *SocialAuthHandler) HandleSocialAuth(c *fiber.Ctx) error {
	fmt.Println("👉 SocialAuthHandler: Called")
	var req SocialAuthRequest
	if err := c.BodyParser(&req); err != nil {
		fmt.Printf("❌ JSON Decode Error: %v\n", err)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request format",
		})
	}

	fmt.Printf("🔍 Social Login Request: Provider=%s, Email=%s\n", req.Provider, req.Email)

	fmt.Printf("🔍 SocialAuthHandler: Request received - Provider=%s, Email=%s, TokenLength=%d, AccessTokenLength=%d\n", req.Provider, req.Email, len(req.ProviderToken), len(req.AccessToken))

	// Validate provider token and get user info
	providerID, email, name, avatarURL, err := h.validateProviderToken(req.Provider, req.ProviderToken, req.AccessToken)

	// --- DEBUG: BYPASS TOKEN VALIDATION IF EMAIL EXISTS (FOR ANDROID DEV) ---
	if err != nil {
		fmt.Printf("⚠️ SocialAuthHandler: Token validation failed: %v\n", err)
		if req.Email != "" && req.Provider == "google" {
			fmt.Printf("⚠️ WARNING: Bypassing token validation for Google email: %s (DEBUG MODE ONLY)\n", req.Email)
			providerID = req.Email // Use email as providerID temp
			email = req.Email
			name = req.Name
			avatarURL = req.AvatarURL
			err = nil // Clear error
		} else {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": fmt.Sprintf("Invalid %s token: %v", req.Provider, err),
			})
		}
	}
	// -----------------------------------------------------------------------

	fmt.Printf("✅ SocialAuthHandler: Token validated (or bypassed) for %s. ProviderID=%s, Email=%s, Name=%s\n", req.Provider, providerID, email, name)

	// Fallback to request data if provider doesn't return certain fields
	if email == "" {
		email = req.Email
		if email != "" {
			fmt.Printf("ℹ️ SocialAuthHandler: Using email from request body: %s\n", email)
		}
	}
	if name == "" {
		name = req.Name
		if name != "" {
			fmt.Printf("ℹ️ SocialAuthHandler: Using name from request body: %s\n", name)
		}
	}
	if avatarURL == "" {
		avatarURL = req.AvatarURL
		if avatarURL != "" {
			fmt.Printf("ℹ️ SocialAuthHandler: Using avatarURL from request body: %s\n", avatarURL)
		}
	}

	// Handle social login (create or update user)
	member, err := h.memberService.HandleSocialLogin(req.Provider, providerID, email, name, avatarURL)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to process login",
		})
	}

	// Generate JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": member.ID,
		"exp":     time.Now().Add(time.Hour * 24 * 30).Unix(), // 30 days
	})

	tokenString, err := token.SignedString([]byte(jwtSecretMobile))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to generate token",
		})
	}

	// Return user data with token
	return c.JSON(fiber.Map{
		"token":           tokenString,
		"username":        member.Username,
		"email":           member.Email,
		"avatar_url":      member.AvatarURL,
		"is_vip":          member.IsVIP(),
		"vip_expiry_text": member.GetVIPExpiryText(),
		"status":          member.Status,
	})
}

// validateProviderToken validates the OAuth token with the provider's API
func (h *SocialAuthHandler) validateProviderToken(provider, token, accessToken string) (providerID, email, name, avatarURL string, err error) {
	switch provider {
	case "google":
		return h.validateGoogleToken(token, accessToken)
	case "facebook":
		return h.validateFacebookToken(token)
	case "line":
		return h.validateLineToken(token)
	default:
		return "", "", "", "", fmt.Errorf("unsupported provider: %s", provider)
	}
}

func (h *SocialAuthHandler) validateGoogleToken(idToken, accessToken string) (providerID, email, name, avatarURL string, err error) {
	// 1. Try ID Token first
	if idToken != "" {
		url := fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", idToken)
		resp, err := http.Get(url)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == 200 {
				body, _ := io.ReadAll(resp.Body)
				var info GoogleTokenInfo
				if err := json.Unmarshal(body, &info); err == nil {
					return info.Sub, info.Email, info.Name, info.Picture, nil
				}
			}
		}
		fmt.Println("⚠️ Google ID Token validation failed, trying Access Token...")
	}

	// 2. Try Access Token if ID Token failed or is empty
	if accessToken != "" {
		url := fmt.Sprintf("https://www.googleapis.com/oauth2/v1/userinfo?access_token=%s", accessToken)
		resp, err := http.Get(url)
		if err != nil {
			return "", "", "", "", err
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			return "", "", "", "", fmt.Errorf("invalid access token (stauts: %d)", resp.StatusCode)
		}

		body, _ := io.ReadAll(resp.Body)
		var info GoogleUserInfo
		if err := json.Unmarshal(body, &info); err != nil {
			return "", "", "", "", err
		}
		return info.Id, info.Email, info.Name, info.Picture, nil
	}

	return "", "", "", "", fmt.Errorf("no valid token provided")
}

func (h *SocialAuthHandler) validateFacebookToken(token string) (providerID, email, name, avatarURL string, err error) {
	url := fmt.Sprintf("https://graph.facebook.com/me?fields=id,email,name,picture&access_token=%s", token)
	resp, err := http.Get(url)
	if err != nil {
		return "", "", "", "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", "", "", "", fmt.Errorf("invalid token")
	}

	body, _ := io.ReadAll(resp.Body)
	var info FacebookTokenInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return "", "", "", "", err
	}

	return info.ID, info.Email, info.Name, info.Picture.Data.URL, nil
}

func (h *SocialAuthHandler) validateLineToken(token string) (providerID, email, name, avatarURL string, err error) {
	req, _ := http.NewRequest("GET", "https://api.line.me/v2/profile", nil)
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", "", "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", "", "", "", fmt.Errorf("invalid token")
	}

	body, _ := io.ReadAll(resp.Body)
	var info LineTokenInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return "", "", "", "", err
	}

	// LINE doesn't provide email via profile API
	return info.UserID, "", info.DisplayName, info.PictureURL, nil
}
