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
	err := godotenv.Overload()
	if err != nil {
		log.Printf("Warning: Error loading .env file: %v", err)
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Println("CRITICAL WARNING: GEMINI_API_KEY is empty!")
	}

	db := setupDatabase()
	defer db.Close()

	// --- Services & Repos ---
	linguisticService, _ := service.NewLinguisticService(apiKey)
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)
	numberPairCache := setupNumberPairCache(db)

	sampleNamesRepo := repository.NewPostgresSampleNamesRepository(db)
	sampleNamesCache := cache.NewSampleNamesCache(sampleNamesRepo)
	sampleNamesCache.EnsureLoaded()
	fmt.Println("Sample names cache is ready.")

	namesMiracleRepo := repository.NewPostgresNamesMiracleRepository(db)
	numerologySvc := service.NewNumerologyService(numerologyCache, shadowCache, klakiniCache, numberPairCache)

	memberRepo := repository.NewPostgresMemberRepository(db)
	memberService := service.NewMemberService(memberRepo)
	savedNameRepo := repository.NewPostgresSavedNameRepository(db)
	savedNameService := service.NewSavedNameService(savedNameRepo)
	articleRepo := repository.NewPostgresArticleRepository(db)
	articleService := service.NewArticleService(articleRepo)
	adminService := service.NewAdminService(memberRepo, articleRepo, sampleNamesRepo, namesMiracleRepo, numerologySvc)

	buddhistDayRepo := repository.NewPostgresBuddhistDayRepository(db)
	buddhistDayService := service.NewBuddhistDayService(buddhistDayRepo)

	walletColorRepo := repository.NewPostgresWalletColorRepository(db)
	walletColorService := service.NewWalletColorService(walletColorRepo)

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
		sess, _ := store.Get(c)

		// Set login status
		var memberID int
		if uid, ok := sess.Get("member_id").(int); ok {
			memberID = uid
			c.Locals("IsLoggedIn", true)
		} else {
			c.Locals("IsLoggedIn", false)
		}

		c.Locals("IsAdmin", sess.Get("is_admin") == true)

		// Check VIP Status Logic
		isVipSession := sess.Get("is_vip") == true

		// If Logged In, FORCE FETCH LATEST STATUS FROM DB to ensure real-time update after payment
		if c.Locals("IsLoggedIn").(bool) {
			// Fetch Member from DB to get real-time status
			member, err := memberRepo.GetByID(memberID)
			if err == nil && member != nil {
				isRealTimeVIP := member.IsVIP()
				c.Locals("IsVIP", isRealTimeVIP)

				// Optional: Sync session if changed
				if isRealTimeVIP != isVipSession {
					sess.Set("is_vip", isRealTimeVIP)
					sess.Save()
				}
				fmt.Printf("DEBUG: Users Logged In. DB Status=%d. RealTime IsVIP=%v\n", member.Status, isRealTimeVIP)
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

	// --- Handlers ---
	// --- Handlers ---
	numerologyHandler := handler.NewNumerologyHandler(numerologyCache, shadowCache, klakiniCache, numberPairCache, namesMiracleRepo, linguisticService, sampleNamesCache)
	memberHandler := handler.NewMemberHandler(memberService, savedNameService, buddhistDayService, klakiniCache, numberPairCache, store)
	savedNameHandler := handler.NewSavedNameHandler(savedNameService, klakiniCache, numberPairCache, store)
	articleHandler := handler.NewArticleHandler(articleService, store)
	adminHandler := handler.NewAdminHandler(adminService, sampleNamesCache, store, buddhistDayService, walletColorService)

	orderRepo := repository.NewPostgresOrderRepository(db)
	paymentService := service.NewPaymentService(orderRepo, memberRepo)
	// We need to pass store to paymentHandler if we want to read session user_id
	paymentHandler := handler.NewPaymentHandler(paymentService, store)
	seoHandler := handler.NewSEOHandler(articleService)

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
						c.Locals("user_id", int(userID))
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

	app.Get("/", func(c *fiber.Ctx) error {
		// Fetch pinned articles
		articles, err := articleService.GetAllArticles()
		if err != nil {
			log.Printf("ERROR: Failed to fetch articles: %v", err)
		}
		var pinnedArticles []domain.Article
		if err == nil {
			log.Printf("DEBUG: Fetched %d articles total", len(articles))
			for _, a := range articles {
				if a.PinOrder > 0 && a.PinOrder <= 10 {
					pinnedArticles = append(pinnedArticles, a)
				}
			}
			log.Printf("DEBUG: Found %d pinned articles", len(pinnedArticles))
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
			"home",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			pages.Landing(pinnedArticles),
		))
	})

	// Buddhist Day Banner Route (HTMX)
	app.Get("/buddhist-day-banner", func(c *fiber.Ctx) error {
		days, err := buddhistDayService.GetUpcomingDays(1)
		if err != nil || len(days) == 0 {
			return c.SendString("") // No upcoming days or error
		}

		nextDay := days[0]
		today := time.Now().Truncate(24 * time.Hour)
		targetDay := nextDay.Date.Truncate(24 * time.Hour)

		// Check if today is the buddhist day
		if today.Equal(targetDay) {
			return c.SendString(`
				<div class="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 mb-4" role="alert">
					<p class="font-bold">วันนี้วันพระ</p>
					<p>ขอให้ท่านมีความสุขกาย สุขใจ คิดสิ่งใดสมปรารถนา</p>
				</div>
			`)
		}

		// Check if tomorrow is the buddhist day
		tomorrow := today.Add(24 * time.Hour)
		if tomorrow.Equal(targetDay) {
			return c.SendString(`
				<div class="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-4" role="alert">
					<p class="font-bold">พรุ่งนี้วันพระ</p>
					<p>เตรียมตัวทำบุญ ตักบาตร เพื่อความเป็นสิริมงคล</p>
				</div>
			`)
		}

		return c.SendString("")
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
			"about",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			pages.About(),
		))
	})

	// Analyzer Page
	app.Get("/analyzer", numerologyHandler.AnalyzeStreaming)

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
	api.Get("/analyze", numerologyHandler.AnalyzeAPI)
	api.Get("/analyze-linguistically", numerologyHandler.AnalyzeLinguisticallyAPI)
	api.Get("/sample-names", numerologyHandler.GetSampleNamesAPI)
	api.Post("/saved-names", optionalAuthMiddleware, savedNameHandler.SaveName)
	app.Delete("/api/saved-names/:id", optionalAuthMiddleware, savedNameHandler.DeleteSavedName)
	api.Get("/payment/upgrade", optionalAuthMiddleware, paymentHandler.GetUpgradeModalAPI)
	api.Get("/payment/status/:refNo", optionalAuthMiddleware, paymentHandler.CheckPaymentStatus)
	api.Get("/articles", articleHandler.GetArticlesJSON)
	api.Get("/articles/:slug", articleHandler.GetArticleBySlugJSON) // New Endpoint
	api.Get("/buddhist-days", adminHandler.GetBuddhistDaysJSON)
	api.Get("/buddhist-days/upcoming", adminHandler.GetUpcomingBuddhistDayJSON)
	api.Get("/buddhist-days/check", adminHandler.CheckIsBuddhistDayJSON)

	// Auth routes
	app.Get("/login", memberHandler.ShowLoginPage)
	app.Post("/login", memberHandler.HandleLogin)
	app.Post("/api/login", memberHandler.HandleLoginAPI)
	app.Post("/api/register", memberHandler.HandleRegisterAPI)
	app.Get("/api/dashboard", memberHandler.GetDashboardAPI) // New Dashboard API
	app.Get("/register", memberHandler.ShowRegisterPage)
	app.Post("/register", memberHandler.HandleRegister)
	app.Get("/logout", memberHandler.HandleLogout)

	// Protected routes
	dashboard := app.Group("/dashboard", authMiddleware)
	dashboard.Get("/", memberHandler.ShowDashboard)

	// Saved Names Routes
	// POST /saved-names uses optional auth middleware to support both JWT and session
	app.Post("/saved-names", optionalAuthMiddleware, savedNameHandler.SaveName)

	// Other saved-names routes CAN use authMiddleware
	savedNames := app.Group("/saved-names", authMiddleware)
	savedNames.Get("/", savedNameHandler.GetSavedNames)
	savedNames.Delete("/:id", optionalAuthMiddleware, savedNameHandler.DeleteSavedName)

	// Admin Routes
	admin := app.Group("/admin", authMiddleware, adminMiddleware)
	admin.Get("/", adminHandler.ShowDashboard)
	admin.Get("/users", adminHandler.ShowUsersPage)
	admin.Post("/users/:id/status", adminHandler.UpdateUserStatus)
	admin.Delete("/users/:id", adminHandler.DeleteUser)
	admin.Get("/articles", adminHandler.ShowArticlesPage)
	admin.Get("/articles/create", adminHandler.ShowCreateArticlePage)
	admin.Post("/articles/create", adminHandler.CreateArticle)
	admin.Get("/articles/edit/:id", adminHandler.ShowEditArticlePage)
	admin.Post("/articles/edit/:id", adminHandler.UpdateArticle)
	admin.Delete("/articles/:id", adminHandler.DeleteArticle)

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

	// Buddhist Day Management
	admin.Get("/buddhist-days", adminHandler.ShowBuddhistDaysPage)
	admin.Post("/buddhist-days", adminHandler.AddBuddhistDay)
	admin.Delete("/buddhist-days/:id", adminHandler.DeleteBuddhistDay)

	// API Docs
	admin.Get("/api-docs", adminHandler.ShowAPIDocsPage)

	// Wallet Color Management
	admin.Get("/wallet-colors", adminHandler.ShowWalletColorsPage)
	admin.Get("/wallet-colors/:day/edit", adminHandler.ShowEditWalletColorRow)
	admin.Post("/wallet-colors/:day", adminHandler.UpdateWalletColor)
	admin.Get("/wallet-colors/:day/cancel", adminHandler.CancelEditWalletColorRow)
	admin.Get("/customer-color-report", adminHandler.ShowCustomerColorReportPage)
	admin.Post("/assign-customer-colors", adminHandler.AssignCustomerColors)

	// Payment Routes
	app.Get("/payment/upgrade", paymentHandler.GetUpgradeModal)
	app.Post("/api/mock-payment/success", paymentHandler.SimulatePaymentSuccess)
	app.Get("/payment/reset", paymentHandler.ResetPayment)
	app.Post("/api/pay/willback", paymentHandler.HandlePaymentWebhook)       // PaySolutions Webhook
	app.Get("/api/payment/status/:refNo", paymentHandler.CheckPaymentStatus) // Polling Endpoint

	log.Println("Starting server on port 3000...")
	log.Fatal(app.Listen(":3000"))
}

// ... (setup functions remain the same) ...
func setupDatabase() *sql.DB {
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable client_encoding=UTF8",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))
	db, _ := sql.Open("postgres", psqlInfo)
	db.Ping()
	fmt.Println("Successfully connected to database!")
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
