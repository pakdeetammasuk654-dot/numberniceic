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
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/session"
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
	sampleNamesCache := setupSampleNamesCache(db)
	namesMiracleRepo := repository.NewPostgresNamesMiracleRepository(db)
	memberRepo := repository.NewPostgresMemberRepository(db)
	memberService := service.NewMemberService(memberRepo)
	savedNameRepo := repository.NewPostgresSavedNameRepository(db)
	savedNameService := service.NewSavedNameService(savedNameRepo)
	articleRepo := repository.NewPostgresArticleRepository(db)
	articleService := service.NewArticleService(articleRepo)
	adminService := service.NewAdminService(memberRepo, articleRepo)

	// --- Session Store ---
	store := session.New(session.Config{
		CookieHTTPOnly: true,
		Expiration:     24 * time.Hour,
	})

	// --- Fiber App ---
	app := fiber.New()
	app.Use(recover.New())
	app.Static("/", "./static")

	// --- Central Middleware for Session Data ---
	app.Use(func(c *fiber.Ctx) error {
		sess, _ := store.Get(c)

		// Set login status
		c.Locals("IsLoggedIn", sess.Get("member_id") != nil)
		c.Locals("IsAdmin", sess.Get("is_admin") == true)
		c.Locals("IsVIP", sess.Get("is_vip") == true)

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
	numerologyHandler := handler.NewNumerologyHandler(numerologyCache, shadowCache, klakiniCache, numberPairCache, namesMiracleRepo, linguisticService, sampleNamesCache)
	memberHandler := handler.NewMemberHandler(memberService, savedNameService, klakiniCache, numberPairCache, store)
	savedNameHandler := handler.NewSavedNameHandler(savedNameService, klakiniCache, numberPairCache, store)
	articleHandler := handler.NewArticleHandler(articleService, store)
	adminHandler := handler.NewAdminHandler(adminService)

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

	// --- Routes ---

	// Landing Page
	app.Get("/", func(c *fiber.Ctx) error {
		// Fetch pinned articles
		articles, err := articleService.GetAllArticles()
		var pinnedArticles []domain.Article
		if err == nil {
			for _, a := range articles {
				if a.PinOrder > 0 && a.PinOrder <= 10 {
					pinnedArticles = append(pinnedArticles, a)
				}
			}
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
			"ยินดีต้อนรับ",
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
			"home",
			getLocStr("toast_success"),
			getLocStr("toast_error"),
			pages.Landing(pinnedArticles),
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
			"เกี่ยวกับเรา",
			c.Locals("IsLoggedIn").(bool),
			c.Locals("IsAdmin").(bool),
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

	// Auth routes
	app.Get("/login", memberHandler.ShowLoginPage)
	app.Post("/login", memberHandler.HandleLogin)
	app.Get("/register", memberHandler.ShowRegisterPage)
	app.Post("/register", memberHandler.HandleRegister)
	app.Get("/logout", memberHandler.HandleLogout)

	// Protected routes
	dashboard := app.Group("/dashboard", authMiddleware)
	dashboard.Get("/", memberHandler.ShowDashboard)

	// Saved Names Routes
	// POST /saved-names does NOT use authMiddleware because it handles 401 internally for HTMX
	app.Post("/saved-names", savedNameHandler.SaveName)

	// Other saved-names routes CAN use authMiddleware
	savedNames := app.Group("/saved-names", authMiddleware)
	savedNames.Get("/", savedNameHandler.GetSavedNames)
	savedNames.Delete("/:id", savedNameHandler.DeleteSavedName)

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

func setupSampleNamesCache(db *sql.DB) *cache.SampleNamesCache {
	repo := repository.NewPostgresSampleNamesRepository(db)
	c := cache.NewSampleNamesCache(repo)
	c.EnsureLoaded()
	fmt.Println("Sample names cache is ready.")
	return c
}
