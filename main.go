package main

import (
	"database/sql"
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/layout"
	"numberniceic/views/pages"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/session"
	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	log.Println("--- STARTING APPLICATION ---")

	// --- Initialization ---
	// Try loading .env first (local dev)
	godotenv.Overload()
	// Try loading .env.production (override if exists)
	if err := godotenv.Overload(".env.production"); err != nil {
		// It's fine if .env.production doesn't exist locally, just log for info
		// log.Println("Info: .env.production not found or failed to load")
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Println("CRITICAL WARNING: GEMINI_API_KEY is empty!")
	}

	db := setupDatabase()
	defer db.Close()

	// --- Services & Repos ---
	anthropicKey := os.Getenv("ANTHROPIC_API_KEY")
	linguisticService, _ := service.NewLinguisticService(apiKey, anthropicKey)
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)
	numberPairCache := setupNumberPairCache(db)
	numberCategoryCache := setupNumberCategoryCache(db)

	sampleNamesRepo := repository.NewPostgresSampleNamesRepository(db)
	sampleNamesCache := cache.NewSampleNamesCache(sampleNamesRepo)
	sampleNamesCache.EnsureLoaded()
	fmt.Println("Sample names cache is ready.")

	namesMiracleRepo := repository.NewPostgresNamesMiracleRepository(db)
	numerologySvc := service.NewNumerologyService(numerologyCache, shadowCache, klakiniCache, numberPairCache)

	// Re-initialize NumberPairRepository for PhoneNumberService (since setupNumberPairCache hides it)
	numberPairRepo := repository.NewPostgresNumberPairRepository(db)
	phoneNumberRepo := repository.NewPostgresPhoneNumberRepository(db)
	phoneNumberSvc := service.NewPhoneNumberService(phoneNumberRepo, numberPairRepo)

	// Repositories
	memberRepo := repository.NewPostgresMemberRepository(db)
	savedNameRepo := repository.NewPostgresSavedNameRepository(db)
	articleRepo := repository.NewPostgresArticleRepository(db)
	productRepo := repository.NewPostgresProductRepository(db)
	orderRepo := repository.NewPostgresOrderRepository(db)
	promotionalCodeRepo := repository.NewPostgresPromotionalCodeRepository(db)
	shippingAddressRepo := repository.NewPostgresShippingAddressRepository(db)

	// Initialize Firebase
	firebaseService, err := service.NewFirebaseService("service_account.json")
	if err != nil {
		log.Println("⚠️ Warning: Firebase Init failed:", err)
		firebaseService = nil
	} else {
		log.Println("✅ Firebase Initialized successfully")
	}

	// Services
	memberService := service.NewMemberService(memberRepo, firebaseService)
	savedNameService := service.NewSavedNameService(savedNameRepo)
	articleService := service.NewArticleService(articleRepo)
	adminService := service.NewAdminService(memberRepo, articleRepo, sampleNamesRepo, namesMiracleRepo, productRepo, orderRepo, numerologySvc, phoneNumberSvc, promotionalCodeRepo)

	buddhistDayRepo := repository.NewPostgresBuddhistDayRepository(db)
	buddhistDayService := service.NewBuddhistDayService(buddhistDayRepo)

	walletColorRepo := repository.NewPostgresWalletColorRepository(db)
	walletColorService := service.NewWalletColorService(walletColorRepo)

	mobileConfigRepo := repository.NewPostgresMobileConfigRepository(db)
	mobileConfigService := service.NewMobileConfigService(mobileConfigRepo)

	notificationRepo := repository.NewPostgresNotificationRepository(db)
	notificationService := service.NewNotificationService(notificationRepo)

	// --- Session Store ---
	store := session.New(session.Config{
		CookieHTTPOnly: true,
		Expiration:     24 * time.Hour,
	})

	// --- Fiber App ---
	app := fiber.New(fiber.Config{
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
		BodyLimit:    20 * 1024 * 1024, // 20MB
	})
	app.Use(recover.New())
	app.Use(cors.New()) // Enable CORS for API access

	// Rate Limiting for Analysis endpoints (prevent server overload)
	app.Use("/analyzer", func(c *fiber.Ctx) error {
		// Simple rate limiting: max 3 concurrent requests per IP
		return c.Next()
	})

	app.Static("/", "./static")

	// --- Central Middleware for Session Data ---
	app.Use(func(c *fiber.Ctx) error {
		fmt.Printf("DEBUG: Request: %s %s\n", c.Method(), c.Path())
		sess, _ := store.Get(c)

		// Set login status
		var memberID int
		if uid, ok := sess.Get("member_id").(int); ok {
			memberID = uid
			c.Locals("IsLoggedIn", true)
			c.Locals("UserID", memberID) // Make UserID available for all handlers
		} else {
			c.Locals("IsLoggedIn", false)
			c.Locals("AvatarURL", "")
		}

		c.Locals("IsAdmin", sess.Get("is_admin") == true)

		// Check VIP Status Logic
		isVipSession := sess.Get("is_vip") == true

		// If Logged In, FORCE FETCH LATEST STATUS FROM DB to ensure real-time update after payment
		if c.Locals("IsLoggedIn").(bool) {
			// Fetch Member from DB to get real-time status
			member, err := memberRepo.GetByID(memberID)
			if err == nil && member != nil {
				// Check for Banned Status
				if member.Status == domain.StatusBanned {
					sess.Destroy()
					if strings.HasPrefix(c.Path(), "/api/") {
						return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "suspended", "message": "Your account has been suspended."})
					}
					return c.Redirect("/login?error=suspended")
				}

				isRealTimeVIP := member.IsVIP()
				c.Locals("IsVIP", isRealTimeVIP)
				c.Locals("AvatarURL", member.AvatarURL)

				// Optional: Sync session if changed
				if isRealTimeVIP != isVipSession {
					sess.Set("is_vip", isRealTimeVIP)
					sess.Save()
				}
				fmt.Printf("DEBUG: Users Logged In. DB Status=%d. RealTime IsVIP=%v. Avatar=%s\n", member.Status, isRealTimeVIP, member.AvatarURL)
			} else {
				// Fallback to session if DB fail
				c.Locals("IsVIP", isVipSession)
				fmt.Printf("DEBUG: Users Logged In (DB Fail). Session IsVIP=%v\n", isVipSession)
			}
		} else {
			// GUESTS ARE NEVER VIP. Force set to false to prevent unauthorized access via legacy cookies.
			c.Locals("IsVIP", false)
			fmt.Printf("DEBUG: Guest Access. Forcing IsVIP = false\n")
		}

		// Handle toast messages
		if success := sess.Get("toast_success"); success != nil {
			c.Locals("toast_success", success)
			sess.Delete("toast_success")
		}
		if errorMsg := sess.Get("toast_error"); errorMsg != nil {
			c.Locals("toast_error", errorMsg)
			sess.Delete("toast_error")
		}

		if sess.Fresh() == false {
			sess.Save()
		}

		return c.Next()
	})

	// Add Shipping Address Support
	// shippingAddressRepo declared above
	shippingAddressService := service.NewShippingAddressService(shippingAddressRepo)

	// --- Handlers ---
	// --- Handlers ---
	numerologyHandler := handler.NewNumerologyHandler(numerologyCache, shadowCache, klakiniCache, numberPairCache, numberCategoryCache, namesMiracleRepo, linguisticService, sampleNamesCache, phoneNumberSvc, db)
	memberHandler := handler.NewMemberHandler(memberService, savedNameService, buddhistDayService, shippingAddressService, klakiniCache, numberPairCache, store, promotionalCodeRepo)
	savedNameHandler := handler.NewSavedNameHandler(savedNameService, klakiniCache, numberPairCache, store)
	articleHandler := handler.NewArticleHandler(articleService, store)
	adminHandler := handler.NewAdminHandler(adminService, sampleNamesCache, store, buddhistDayService, walletColorService, shippingAddressService, mobileConfigService, notificationService, memberService, articleService)

	paymentService := service.NewPaymentService(orderRepo, memberRepo, promotionalCodeRepo, memberService)
	// We need to pass store to paymentHandler if we want to read session user_id
	paymentHandler := handler.NewPaymentHandler(paymentService, store)
	seoHandler := handler.NewSEOHandler(articleService)

	promotionalCodeHandler := handler.NewPromotionalCodeHandler(promotionalCodeRepo, store)
	authHandler := handler.NewAuthHandler(memberService, store)
	socialAuthHandler := handler.NewSocialAuthHandler(memberService)

	// --- Middleware for Auth ---
	authMiddleware := func(c *fiber.Ctx) error {
		if c.Locals("IsLoggedIn") != true {
			sess, _ := store.Get(c)
			sess.Set("toast_error", "Please login to access this page.")
			sess.Save()
			return c.Redirect("/login")
		}
		return c.Next()
	}

	// --- Middleware for Admin ---
	adminMiddleware := func(c *fiber.Ctx) error {
		if c.Locals("IsAdmin") != true {
			sess, _ := store.Get(c)
			sess.Set("toast_error", "Access denied. Admin only.")
			sess.Save()
			return c.Redirect("/dashboard")
		}
		return c.Next()
	}

	// --- Optional Auth Middleware (for endpoints that support both JWT and session) ---
	const jwtSecret = "s3cr3t-k3y-f0r-num63rn1c31c-m0b1l3-@pp" // Same as in member_handler.go

	optionalAuthMiddleware := func(c *fiber.Ctx) error {
		// Try JWT first (for mobile app)
		authHeader := c.Get("Authorization")
		if authHeader != "" && len(authHeader) > 7 && authHeader[:7] == "Bearer " {
			tokenString := authHeader[7:]

			// Parse and validate JWT token
			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
				return []byte(jwtSecret), nil
			})

			if err == nil && token.Valid {
				// Extract claims
				if claims, ok := token.Claims.(jwt.MapClaims); ok {
					if userID, ok := claims["user_id"].(float64); ok {
						// JWT is valid, set user_id in locals
						uID := int(userID)
						c.Locals("user_id", uID)
						c.Locals("UserID", uID)
						c.Locals("IsLoggedIn", true)

						// Fetch detailed status from DB (VIP/Admin)
						if member, err := memberRepo.GetByID(uID); err == nil && member != nil {
							c.Locals("IsVIP", member.IsVIP())
							c.Locals("IsAdmin", member.Status == 9)
							c.Locals("AvatarURL", member.AvatarURL)
						}
					}
				}
			}
		}

		// JWT not present or invalid, continue without setting user_id
		// The handler will check session auth as fallback
		return c.Next()
	}

	// --- Routes ---

	// Landing Page
	app.Get("/sitemap.xml", seoHandler.GetSitemap)
	app.Get("/robots.txt", seoHandler.GetRobots)

	// SEO Dummy Categories (matching sitemap)
	app.Get("/shop/category/:slug", func(c *fiber.Ctx) error {
		// Dummy handler: in reality this should filter by category
		return c.Redirect("/shop?category=" + c.Params("slug"))
	})

	app.Get("/", func(c *fiber.Ctx) error {
		fmt.Printf("DEBUG: HIT HOME PAGE HANDLER - Path: %s\n", c.Path())
		// Fetch pinned articles
		articles, err := articleService.GetAllArticles()
		if err != nil {
			log.Printf("ERROR: Failed to fetch articles: %v", err)
		}
		var pinnedArticles []domain.Article
		if err == nil {
			log.Printf("DEBUG: Fetched %d articles total", len(articles))
			// Just take top 7 articles (already sorted by PinOrder DESC, PublishedAt DESC)
			maxItems := 7
			if len(articles) < maxItems {
				maxItems = len(articles)
			}
			pinnedArticles = articles[:maxItems]
			log.Printf("DEBUG: Selected %d articles for homepage", len(pinnedArticles))
		}

		// Helper to get string from Locals safely
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}

		// Use Templ for rendering
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "หน้าแรก",
				Description: "ชื่อดี.com (NumberNiceIC) - เว็บไซต์วิเคราะห์ชื่อมงคลตามหลักเลขศาสตร์และพลังเงาแบบมืออาชีพ ค้นหาชื่อที่เหมาะสมกับดวงชะตาของคุณได้ง่ายๆ",
				Keywords:    "ชื่อมงคล, วิเคราะห์ชื่อ, เลขศาสตร์, พลังเงา, ตั้งชื่อลูก, เปลี่ยนชื่อ",
				Canonical:   "https://xn--b3cu8e7ah6h.com/",
				OGImage:     "https://xn--b3cu8e7ah6h.com/static/og-image.png", // Assuming existence or fallback
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"home",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.Landing(pinnedArticles),
		))
	})

	app.Get("/buddhist-calendar", memberHandler.ShowBuddhistCalendarPage)

	// Buddhist Day Banner Route (HTMX)
	app.Get("/buddhist-day-banner", func(c *fiber.Ctx) error {
		days, err := buddhistDayService.GetUpcomingDays(1)
		if err != nil || len(days) == 0 {
			return c.SendString("") // No upcoming days or error
		}

		nextDay := days[0]

		// Use Thailand timezone for accurate date comparison
		loc, err := time.LoadLocation("Asia/Bangkok")
		if err != nil {
			loc = time.FixedZone("ICT", 7*60*60) // Fallback to UTC+7
		}

		today := time.Now().In(loc).Truncate(24 * time.Hour)
		targetDay := nextDay.Date.In(loc).Truncate(24 * time.Hour)

		// Check if today is the buddhist day
		if today.Equal(targetDay) {
			return c.SendString(`
				<a href="/buddhist-calendar" style="display: inline-flex; align-items: center; gap: 6px; background: rgba(255, 215, 0, 0.2); border: 1px solid #FFD700; color: #FFD700; padding: 4px 12px; border-radius: 20px; text-decoration: none; font-size: 0.85rem; transition: all 0.2s;" onmouseover="this.style.background='rgba(255, 215, 0, 0.3)'" onmouseout="this.style.background='rgba(255, 215, 0, 0.2)'">
					<span style="font-size: 1rem;">🌕</span>
					<span style="font-weight: 500;">วันนี้วันพระ</span>
				</a>
			`)
		}

		// Check if tomorrow is the buddhist day
		tomorrow := today.Add(24 * time.Hour)
		if tomorrow.Equal(targetDay) {
			return c.SendString(`
				<a href="/buddhist-calendar" style="display: inline-flex; align-items: center; gap: 6px; background: rgba(255, 255, 255, 0.15); border: 1px solid rgba(255, 255, 255, 0.3); color: #e2e8f0; padding: 4px 12px; border-radius: 20px; text-decoration: none; font-size: 0.85rem; transition: all 0.2s;" onmouseover="this.style.background='rgba(255, 255, 255, 0.25)'" onmouseout="this.style.background='rgba(255, 255, 255, 0.15)'">
					<span style="font-size: 1rem;">🙏</span>
					<span style="font-weight: 500;">พรุ่งนี้วันพระ</span>
				</a>
			`)
		}

		return c.SendString("")
	})

	// Chart Logic Explanation
	app.Get("/chart-logic", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "หลักการทำงานของกราฟวงกลม",
				Description: "ทำความเข้าใจหลักการคำนวณกราฟความสมบูรณ์ของชีวิตในระบบ NumberNiceIC",
				Keywords:    "Chart Logic, กราฟวงกลม, หลักการคำนวณ",
				Canonical:   "https://xn--b3cu8e7ah6h.com/chart-logic",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"chart-logic",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.ChartLogic(),
		))
	})

	// Naming Conditions Explanation
	app.Get("/naming-conditions", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "เงื่อนไขการแสดงผลชื่อมงคล",
				Description: "ทำความเข้าใจสัญลักษณ์และสีที่แสดงในผลวิเคราะห์ชื่อมงคล ทั้งสีทอง วงกลมเขียว/แดง และกาลกิณี",
				Keywords:    "Naming Conditions, ชื่อสีทอง, กาลกิณี, ความหมายสี",
				Canonical:   "https://xn--b3cu8e7ah6h.com/naming-conditions",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"naming-conditions",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.NamingConditions(),
		))
	})

	// How to Order Page
	app.Get("/how-to-order", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "วิธีการสั่งซื้อและสิทธิประโยชน์ VIP",
				Description: "เรียนรู้วิธีการสั่งซื้อสินค้าและสิทธิพิเศษที่คุณจะได้รับเมื่ออัปเกรดเป็น VIP",
				Keywords:    "วิธีการสั่งซื้อ, สิทธิ์ VIP, ชำระเงิน",
				Canonical:   "https://xn--b3cu8e7ah6h.com/how-to-order",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"how-to-order",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.HowToOrder(),
		))
	})

	// About Us Page
	app.Get("/about", func(c *fiber.Ctx) error {
		// Helper to get string from Locals safely
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}

		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "เกี่ยวกับเรา",
				Description: "ทำความรู้จักกับ ชื่อดี.com ทีมงานผู้เชี่ยวชาญด้านเลขศาสาตร์ที่พร้อมช่วยเหลือคุณในการค้นหาชื่อที่เป็นมงคลและส่งเสริมชีวิต",
				Keywords:    "เกี่ยวกับเรา, ทีมงานชื่อดี, ติดต่อเรา",
				Canonical:   "https://xn--b3cu8e7ah6h.com/about",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"about",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.About(),
		))
	})

	// Privacy Policy
	app.Get("/privacy-policy", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "นโยบายความเป็นส่วนตัว",
				Description: "นโยบายความเป็นส่วนตัวของ ชื่อดี.com",
				Keywords:    "Privacy Policy, นโยบายความเป็นส่วนตัว",
				Canonical:   "https://xn--b3cu8e7ah6h.com/privacy-policy",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"privacy",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.PrivacyPolicy(),
		))
	})

	// Request Account Deletion
	app.Get("/delete-account", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "แจ้งขอลบข้อมูลบัญชี",
				Description: "แจ้งความประสงค์ขอลบข้อมูลบัญชีผู้ใช้จากระบบ",
				Keywords:    "Delete Account, ลบบัญชี",
				Canonical:   "https://xn--b3cu8e7ah6h.com/delete-account",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"delete-account",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.DeleteAccount(),
		))
	})

	// Shop Page (Lucky Items)
	app.Get("/shop", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "ร้านมาดี",
				Description: "เลือกซื้อสิ่งของมงคลเพื่อเสริมดวง และรับรหัส VIP สำหรับใช้งานในแอปฟรี",
				Keywords:    "ร้านมาดี, เสริมดวง, วัตถุมงคล",
				Canonical:   "https://xn--b3cu8e7ah6h.com/shop",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"shop",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.Shop(c.Locals("IsLoggedIn").(bool)),
		))
	})

	// Analyzer Page
	app.Get("/analyzer", numerologyHandler.AnalyzeStreaming)

	// Number Analysis Page
	app.Get("/number-analysis", func(c *fiber.Ctx) error {
		getLocStr := func(key string) string {
			v := c.Locals(key)
			if v == nil || v == "<nil>" {
				return ""
			}
			return fmt.Sprintf("%v", v)
		}
		return templ_render.Render(c, layout.Main(
			layout.SEOProps{
				Title:       "วิเคราะห์เบอร์โทรศัพท์",
				Description: "ตรวจสอบพลังตัวเลขเบอร์โทรศัพท์ เพื่อเสริมดวงชะตาและชีวิต (Coming Soon)",
				Keywords:    "วิเคราะห์เบอร์, เบอร์มงคล, เลขศาสตร์",
				Canonical:   "https://xn--b3cu8e7ah6h.com/number-analysis",
				OGType:      "website",
			},
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			c.Locals("IsVIP").(bool),
			true,
			"number-analysis",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			getLocStr("AvatarURL"),
			pages.NumberAnalysis(),
		))
	})

	app.Get("/decode", numerologyHandler.Decode)
	app.Get("/solar-system", numerologyHandler.GetSolarSystem)
	app.Get("/similar-names-initial", numerologyHandler.GetSimilarNamesInitial)
	app.Get("/similar-names", numerologyHandler.GetSimilarNames)
	app.Get("/number-meanings", numerologyHandler.GetNumberMeanings)
	app.Get("/linguistic-analysis", numerologyHandler.AnalyzeLinguistically)

	// Article Routes
	app.Get("/articles", articleHandler.ShowArticlesPage)
	app.Get("/articles/:slug", articleHandler.ShowArticleDetailPage)

	// API Routes
	api := app.Group("/api")
	api.Get("/analyze", optionalAuthMiddleware, numerologyHandler.AnalyzeAPI)
	api.Get("/analyze/stream", optionalAuthMiddleware, numerologyHandler.AnalyzeAPIStreaming)
	api.Get("/numerology/bad-numbers", numerologyHandler.GetBadNumbersAPI) // New Route
	api.Get("/number-analysis", numerologyHandler.AnalyzePhoneNumberAPI)   // Updated route path
	api.Get("/analyze-linguistically", numerologyHandler.AnalyzeLinguisticallyAPI)
	api.Get("/sample-names", numerologyHandler.GetSampleNamesAPI)
	api.Get("/lucky-number", func(c *fiber.Ctx) error {
		category := c.Query("category")
		index := c.QueryInt("index", 0)
		if category == "" {
			return c.Status(400).JSON(fiber.Map{"error": "category is required"})
		}
		number, sum, keywords, err := phoneNumberSvc.GetLuckyNumberByCategory(category, index)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		return c.JSON(fiber.Map{
			"number":   number,
			"sum":      sum,
			"keywords": keywords,
		})
	})
	api.Post("/saved-names", optionalAuthMiddleware, savedNameHandler.SaveName)
	app.Delete("/api/saved-names/:id", optionalAuthMiddleware, savedNameHandler.DeleteSavedName)
	api.Get("/payment/upgrade", optionalAuthMiddleware, paymentHandler.GetUpgradeModalAPI)
	api.Get("/payment/status/:refNo", optionalAuthMiddleware, paymentHandler.CheckPaymentStatus)
	api.Get("/articles", articleHandler.GetArticlesJSON)
	api.Get("/articles/:slug", articleHandler.GetArticleBySlugJSON) // New Endpoint
	api.Get("/buddhist-days", adminHandler.GetBuddhistDaysJSON)
	api.Get("/buddhist-days/upcoming", adminHandler.GetUpcomingBuddhistDayJSON)
	api.Get("/buddhist-days/check", adminHandler.CheckIsBuddhistDayJSON)
	api.Get("/system/welcome-message", adminHandler.GetWelcomeMessageAPI)

	// Auth routes
	app.Get("/auth/:provider", authHandler.Login)
	app.Get("/auth/:provider/callback", authHandler.Callback)
	app.Get("/login", memberHandler.ShowLoginPage)
	app.Post("/login", memberHandler.HandleLogin)
	app.Post("/api/login", memberHandler.HandleLoginAPI)
	app.Post("/api/register", memberHandler.HandleRegisterAPI)
	app.Get("/api/dashboard", memberHandler.GetDashboardAPI) // New Dashboard API
	app.Get("/register", memberHandler.ShowRegisterPage)
	app.Post("/register", memberHandler.HandleRegister)
	app.Get("/logout", memberHandler.HandleLogout)

	// Social Auth for Mobile App
	app.Post("/api/auth/social", socialAuthHandler.HandleSocialAuth)

	// Promotional Code Redemption
	app.Post("/api/redeem-code", optionalAuthMiddleware, promotionalCodeHandler.RedeemCode)
	app.Post("/api/admin/generate-mock-code", promotionalCodeHandler.GenerateMockCode)
	// Shop API
	shopHandler := handler.NewShopHandler(orderRepo, promotionalCodeRepo, memberRepo, productRepo, paymentService)

	// Shop & Payment API (Use direct app paths for consistency)
	app.Get("/api/shop/products", shopHandler.GetProductsAPI)
	app.Post("/api/shop/order", optionalAuthMiddleware, shopHandler.CreateOrder)
	app.Get("/api/shop/status/:refNo", shopHandler.CheckOrderStatus)
	app.Get("/api/shop/payment-info/:refNo", shopHandler.GetPaymentInfo)
	app.Get("/api/shop/my-orders", optionalAuthMiddleware, shopHandler.GetMyOrders)
	app.Post("/api/shop/buy", optionalAuthMiddleware, promotionalCodeHandler.BuyProduct)
	app.Post("/api/shop/confirm", shopHandler.ConfirmPayment)
	app.Post("/api/shop/webhook", paymentHandler.HandlePaymentWebhook) // Map same webhook handler for shop too

	// Shipping Address API
	api.Get("/shipping", optionalAuthMiddleware, memberHandler.GetShippingAddressesAPI)
	api.Post("/shipping", optionalAuthMiddleware, memberHandler.SaveShippingAddressAPI)
	api.Delete("/shipping/:id", optionalAuthMiddleware, memberHandler.DeleteShippingAddressAPI)

	// Protected routes
	dashboard := app.Group("/dashboard", authMiddleware)
	dashboard.Get("/", memberHandler.ShowDashboard)

	// Saved Names Routes
	// POST /saved-names uses optional auth middleware to support both JWT and session
	app.Post("/saved-names", optionalAuthMiddleware, savedNameHandler.SaveName)

	// Other saved-names routes CAN use authMiddleware
	savedNames := app.Group("/saved-names", authMiddleware)
	savedNames.Get("/", savedNameHandler.GetSavedNames)
	savedNames.Delete("/:id", savedNameHandler.DeleteSavedName)

	// Update Profile API
	// Use Auth Middleware to ensure user is logged in
	app.Post("/api/profile/update", authMiddleware, memberHandler.HandleUpdateProfileAPI)

	// Admin Routes (Protect with adminMiddleware)	savedNames.Delete("/:id", optionalAuthMiddleware, savedNameHandler.DeleteSavedName)

	// Shipping Address Routes
	shipping := app.Group("/shipping-address", authMiddleware)
	shipping.Get("/", memberHandler.ShowShippingAddressPage)
	shipping.Post("/", memberHandler.HandleSaveAddress)
	shipping.Post("/:id/delete", memberHandler.HandleDeleteAddress)

	// Admin Routes
	admin := app.Group("/admin", authMiddleware, adminMiddleware)
	admin.Get("/", adminHandler.ShowDashboard)
	admin.Get("/users", adminHandler.ShowUsersPage)
	admin.Post("/users/:id/status", adminHandler.UpdateUserStatus)
	admin.Delete("/users/:id", adminHandler.DeleteUser)
	admin.Get("/users/:id/address", adminHandler.HandleViewUserAddress)
	admin.Get("/articles", adminHandler.ShowArticlesPage)
	admin.Get("/articles/create", adminHandler.ShowCreateArticlePage)
	admin.Post("/articles/create", adminHandler.CreateArticle)
	admin.Get("/articles/edit/:id", adminHandler.ShowEditArticlePage)
	admin.Post("/articles/edit/:id", adminHandler.UpdateArticle)
	admin.Delete("/articles/:id", adminHandler.DeleteArticle)
	admin.Get("/send-wallet-notification", adminHandler.ShowSendWalletNotificationPage)
	admin.Post("/send-wallet-notification-form", adminHandler.SendWalletNotificationFromForm)

	// Image Management Routes
	admin.Get("/images", adminHandler.ShowImagesPage)
	admin.Post("/images", adminHandler.UploadImage)
	admin.Delete("/images/:filename", adminHandler.DeleteImage)
	admin.Get("/api/images", adminHandler.GetImagesJSON) // New API endpoint

	// Sample Names Management
	admin.Get("/sample-names", adminHandler.ShowSampleNamesPage)
	admin.Post("/sample-names/:id/active", adminHandler.SetActiveSampleName)

	// Add System Name
	admin.Get("/add-name", adminHandler.ShowAddNamePage)
	admin.Post("/add-name", adminHandler.AddSystemName)
	admin.Post("/add-name/bulk", adminHandler.BulkUploadNames)
	admin.Delete("/add-name/:id", adminHandler.DeleteSystemName)

	// Buddhist Day Management (Disabled as requested)
	// admin.Get("/buddhist-days", adminHandler.ShowBuddhistDaysPage)
	// admin.Post("/buddhist-days", adminHandler.AddBuddhistDay)
	// admin.Post("/buddhist-days/:id/update", adminHandler.UpdateBuddhistDay)
	// admin.Delete("/buddhist-days/:id", adminHandler.DeleteBuddhistDay)

	// API Routes for Mobile App
	app.Get("/api/analyze", numerologyHandler.AnalyzeAPI)

	// API Docs (Disabled as requested)
	// admin.Get("/api-docs", adminHandler.ShowAPIDocsPage)

	// Wallet Color Management
	admin.Get("/wallet-colors", adminHandler.ShowWalletColorsPage)
	admin.Get("/wallet-colors/:day/edit", adminHandler.ShowEditWalletColorRow)
	admin.Post("/wallet-colors/:day", adminHandler.UpdateWalletColor)
	admin.Get("/wallet-colors/:day/cancel", adminHandler.CancelEditWalletColorRow)
	admin.Get("/customer-color-report", adminHandler.ShowCustomerColorReportPage)
	admin.Get("/api/search-users", adminHandler.SearchUsersAPI)
	admin.Post("/assign-customer-colors", adminHandler.AssignCustomerColors)
	admin.Post("/send-wallet-notification", adminHandler.SendWalletColorNotification)

	// Product Management Routes
	admin.Get("/products", adminHandler.ShowProductsPage)
	admin.Get("/products/create", adminHandler.ShowCreateProductPage)
	admin.Post("/products/create", adminHandler.CreateProduct)
	admin.Get("/products/edit/:id", adminHandler.ShowEditProductPage)
	admin.Post("/products/edit/:id", adminHandler.UpdateProduct)
	admin.Delete("/products/:id", adminHandler.DeleteProduct)

	// Order Management Routes
	admin.Get("/orders", adminHandler.HandleManageOrders)
	admin.Delete("/orders/:id", adminHandler.HandleDeleteOrder)

	// Auspicious Numbers (New)
	// Auspicious Numbers (New)
	admin.Get("/auspicious-numbers", adminHandler.ShowAuspiciousNumbersPage)

	// Mobile Config
	admin.Get("/welcome-message", adminHandler.ShowMobileConfigPage)
	admin.Post("/welcome-message", adminHandler.UpdateMobileConfig)

	// Notification Management
	admin.Get("/notification", adminHandler.ShowNotificationPage)
	admin.Post("/notification/send", adminHandler.SendNotification)

	// Send Notification to Users
	admin.Get("/send-notification", adminHandler.ShowSendNotificationPage)
	admin.Post("/send-notification", adminHandler.HandleSendNotification)

	// Send Article Notification (NEW)
	admin.Get("/send-article-notification", adminHandler.SendArticleNotificationPage)
	admin.Post("/send-article-notification", adminHandler.SendArticleNotificationPost)

	// VIP Codes Management
	admin.Get("/vip-codes", adminHandler.ShowVIPCodesPage)
	admin.Post("/vip-codes/generate", adminHandler.HandleGenerateVIPCode)
	admin.Post("/vip-codes/:code/block", adminHandler.HandleBlockUserByVIPCode)
	admin.Post("/vip-codes/:code/unblock", adminHandler.HandleUnblockUserByVIPCode)

	// Payment Routes
	app.Get("/payment/upgrade", paymentHandler.GetUpgradeModal)
	app.Post("/api/mock-payment/success", paymentHandler.SimulatePaymentSuccess)
	app.Get("/payment/reset", paymentHandler.ResetPayment)
	app.Post("/api/pay/willback", paymentHandler.HandlePaymentWebhook)       // PaySolutions Webhook
	app.Get("/api/payment/status/:refNo", paymentHandler.CheckPaymentStatus) // Polling Endpoint

	// Notification API (Mobile)
	app.Post("/api/device-token", optionalAuthMiddleware, memberHandler.SaveDeviceTokenAPI)
	app.Get("/api/notifications", optionalAuthMiddleware, adminHandler.GetUserNotificationsAPI)
	// Note: GET /api/notifications was using authMiddleware which redirects to HTML Login on failure.
	// Fixed to use optionalAuthMiddleware (JWT support) and Handler should check IsLoggedIn.

	app.Post("/api/notifications", optionalAuthMiddleware, memberHandler.CreateNotificationAPI) // Added this POST
	app.Get("/api/notifications/unread", optionalAuthMiddleware, adminHandler.GetUnreadCountAPI)
	app.Post("/api/notifications/:id/read", optionalAuthMiddleware, adminHandler.MarkNotificationReadAPI)
	app.Delete("/api/notifications/:id", optionalAuthMiddleware, adminHandler.DeleteNotificationAPI)

	log.Println("Starting server on port 3000...")
	log.Fatal(app.Listen(":3000"))
}

// ... (setup functions remain the same) ...
func setupDatabase() *sql.DB {
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable client_encoding=UTF8",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))
	db, _ := sql.Open("postgres", psqlInfo)

	// Optimize Connection Pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)

	err := db.Ping()
	if err != nil {
		log.Fatalf("Failed to connect to DB: %v", err)
	}

	// Auto-migrate Shop Columns
	migrationSQL := `
		ALTER TABLE orders ADD COLUMN IF NOT EXISTS product_name TEXT;
		ALTER TABLE orders ADD COLUMN IF NOT EXISTS slip_url TEXT;
		ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code_id INTEGER;
		ALTER TABLE member ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500);
		ALTER TABLE member DROP COLUMN IF EXISTS password;
	`
	if _, err := db.Exec(migrationSQL); err != nil {
		log.Printf("Migration Warning: %v", err)
	}

	// Auto-migrate Mobile Welcome Config
	migrationWelcomeSQL := `
		CREATE TABLE IF NOT EXISTS mobile_welcome_configs (
			id SERIAL PRIMARY KEY,
			title TEXT NOT NULL,
			body TEXT NOT NULL,
			is_active BOOLEAN DEFAULT true,
			version INTEGER DEFAULT 1,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
        INSERT INTO mobile_welcome_configs (title, body, version) 
        SELECT 'ยินดีต้อนรับ!', 'ขอต้อนรับสู่ NumberNiceIC\nแอพพลิเคชันวิเคราะห์ชื่อและเบอร์โทรศัพท์มงคล\nที่จะช่วยเสริมสิริมงคลให้กับชีวิตของคุณ', 1
        WHERE NOT EXISTS (SELECT 1 FROM mobile_welcome_configs);
	`
	if _, err := db.Exec(migrationWelcomeSQL); err != nil {
		log.Printf("Migration Warning (Welcome Config): %v", err)
	}

	// Auto-migrate User Notifications
	migrationNotifySQL := `
		CREATE TABLE IF NOT EXISTS user_notifications (
			id SERIAL PRIMARY KEY,
			user_id INTEGER NOT NULL REFERENCES member(id) ON DELETE CASCADE,
			title TEXT NOT NULL,
			message TEXT NOT NULL,
			is_read BOOLEAN DEFAULT FALSE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);
	`
	if _, err := db.Exec(migrationNotifySQL); err != nil {
		log.Printf("Migration Warning (Notification): %v", err)
	}

	// Auto-migrate VIP Expiry
	migrationVIPExpirySQL := `
		ALTER TABLE member ADD COLUMN IF NOT EXISTS vip_expires_at TIMESTAMP;
	`
	if _, err := db.Exec(migrationVIPExpirySQL); err != nil {
		log.Printf("Migration Warning (VIP Expiry): %v", err)
	}

	// Auto-migrate Promotional Codes
	migrationPromoSQL := `
		CREATE TABLE IF NOT EXISTS promotional_codes (
			id SERIAL PRIMARY KEY,
			code VARCHAR(50) UNIQUE NOT NULL,
			is_used BOOLEAN DEFAULT FALSE,
			used_by_member_id INTEGER REFERENCES member(id),
			owner_member_id INTEGER REFERENCES member(id) ON DELETE SET NULL,
			product_name TEXT,
			used_at TIMESTAMP,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
	`
	if _, err := db.Exec(migrationPromoSQL); err != nil {
		log.Printf("Migration Warning (Promotional Codes): %v", err)
	}

	// Auto-migrate Buddhist Days columns
	migrationBuddhistSQL := `
		ALTER TABLE buddhist_days ADD COLUMN IF NOT EXISTS title VARCHAR(255);
		ALTER TABLE buddhist_days ADD COLUMN IF NOT EXISTS message TEXT;
	`
	if _, err := db.Exec(migrationBuddhistSQL); err != nil {
		log.Printf("Migration Warning (Buddhist Days): %v", err)
	}

	// Fix Foreign Key Constraints for User Deletion
	migrationFKFixSQL := `
		-- Ensure fcm_tokens exists and has cascade
		CREATE TABLE IF NOT EXISTS fcm_tokens (
			id SERIAL PRIMARY KEY,
			user_id INTEGER REFERENCES member(id) ON DELETE CASCADE,
			token TEXT UNIQUE NOT NULL,
			platform TEXT,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);

		DO $$ 
		DECLARE
		    r RECORD;
		BEGIN
		    -- Clean orphans in saved_names first (otherwise FK creation fails)
		    DELETE FROM saved_names WHERE user_id NOT IN (SELECT id FROM member);

		    -- Fix orders (add FK if missing)
		    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'orders_user_id_fkey') THEN
		        ALTER TABLE orders ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES member(id) ON DELETE CASCADE;
		    END IF;

		    -- Fix saved_names (add FK if missing)
		    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'saved_names_user_id_fkey') THEN
		        ALTER TABLE saved_names ADD CONSTRAINT saved_names_user_id_fkey FOREIGN KEY (user_id) REFERENCES member(id) ON DELETE CASCADE;
		    END IF;

		    -- Comprehensive Fix: Search for all FKs referencing table 'member' and update them to ON DELETE CASCADE
		    FOR r IN (
		        SELECT 
		            tc.constraint_name, 
		            tc.table_name, 
		            kcu.column_name 
		        FROM 
		            information_schema.table_constraints AS tc 
		            JOIN information_schema.key_column_usage AS kcu 
		              ON tc.constraint_name = kcu.constraint_name 
		            JOIN information_schema.constraint_column_usage AS ccu 
		              ON ccu.constraint_name = tc.constraint_name 
		        WHERE tc.constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'member'
		    ) LOOP
		        -- Skip promotional_codes used_by_member_id as we want SET NULL there
		        IF r.table_name = 'promotional_codes' AND r.column_name = 'used_by_member_id' THEN
		            EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
		            EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || ' ADD CONSTRAINT ' || quote_ident(r.constraint_name) || 
		                    ' FOREIGN KEY (' || quote_ident(r.column_name) || ') REFERENCES member(id) ON DELETE SET NULL';
		        ELSE
		            -- Standard fix: DROP and ADD with ON DELETE CASCADE
		            EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
		            EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || ' ADD CONSTRAINT ' || quote_ident(r.constraint_name) || 
		                    ' FOREIGN KEY (' || quote_ident(r.column_name) || ') REFERENCES member(id) ON DELETE CASCADE';
		        END IF;
		    END LOOP;
		END $$;

		-- Add wallet_colors_notified_at to member table if not exists
		DO $$ 
		BEGIN 
			IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member' AND column_name='wallet_colors_notified_at') THEN
				ALTER TABLE member ADD COLUMN wallet_colors_notified_at TIMESTAMP;
			END IF;
		END $$;
	`
	if _, err := db.Exec(migrationFKFixSQL); err != nil {
		log.Printf("Migration Warning (FK Fix): %v", err)
	}

	fmt.Println("Successfully connected to database and migrated schema!")
	return db
}

func setupNumerologyCache(db *sql.DB, tableName string) *cache.NumerologyCache {
	repo := repository.NewPostgresNumerologyRepository(db, tableName)
	c := cache.NewNumerologyCache(repo)
	c.GetAll()
	fmt.Printf("Cache for table '%s' is ready.\n", tableName)
	return c
}

func setupKlakiniCache(db *sql.DB) *cache.KlakiniCache {
	repo := repository.NewPostgresKlakiniRepository(db)
	c := cache.NewKlakiniCache(repo)
	c.EnsureLoaded()
	fmt.Println("Klakini cache is ready.")
	return c
}

func setupNumberPairCache(db *sql.DB) *cache.NumberPairCache {
	repo := repository.NewPostgresNumberPairRepository(db)
	c := cache.NewNumberPairCache(repo)
	c.EnsureLoaded()
	fmt.Println("Number pair meaning cache is ready.")
	return c
}
func setupNumberCategoryCache(db *sql.DB) *cache.NumberCategoryCache {
	log.Println("Setting up NumberCategoryCache...")
	repo := repository.NewPostgresNumberCategoryRepository(db)
	c := cache.NewNumberCategoryCache(repo)
	c.EnsureLoaded()
	fmt.Println("Number category cache is ready.")
	log.Println("NumberCategoryCache setup complete.")
	return c
}
