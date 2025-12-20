package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler"
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/service"
	"os"
	"reflect"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/session"
	"github.com/gofiber/template/html/v2"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

// toFloat64 helper
func toFloat64(v interface{}) (float64, error) {
	val := reflect.ValueOf(v)
	switch val.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return float64(val.Int()), nil
	case reflect.Float32, reflect.Float64:
		return val.Float(), nil
	default:
		return 0, fmt.Errorf("unable to convert %T to float64", v)
	}
}

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

	// Explicitly define the layout for the template engine
	engine := html.New("./views", ".html")
	engine.Reload(true)
	// engine.Layout("main") // REMOVED: This causes recursive layout calls when templates also define it.

	// --- Template Functions ---
	engine.AddFunc("mul", func(a, b interface{}) (float64, error) {
		fa, _ := toFloat64(a)
		fb, _ := toFloat64(b)
		return fa * fb, nil
	})
	engine.AddFunc("div", func(a, b interface{}) (float64, error) {
		fa, _ := toFloat64(a)
		fb, _ := toFloat64(b)
		if fb == 0 {
			return 0, nil
		}
		return fa / fb, nil
	})
	engine.AddFunc("add", func(a, b interface{}) (float64, error) {
		fa, _ := toFloat64(a)
		fb, _ := toFloat64(b)
		return fa + fb, nil
	})
	engine.AddFunc("mod", func(a, b int) int { return a % b })
	engine.AddFunc("printf", fmt.Sprintf)
	engine.AddFunc("HTML", func(s string) template.HTML { return template.HTML(s) })

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

	// --- Session Store ---
	store := session.New(session.Config{
		CookieHTTPOnly: true,
		Expiration:     24 * time.Hour,
	})

	// --- Fiber App ---
	app := fiber.New(fiber.Config{Views: engine})
	app.Use(recover.New())
	app.Static("/", "./static")

	// --- Central Middleware for Session Data ---
	app.Use(func(c *fiber.Ctx) error {
		sess, _ := store.Get(c)

		// Set login status
		c.Locals("IsLoggedIn", sess.Get("member_id") != nil)

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
	numerologyHandler := handler.NewNumerologyHandler(numerologyCache, shadowCache, klakiniCache, numberPairCache, namesMiracleRepo, linguisticService)
	memberHandler := handler.NewMemberHandler(memberService, savedNameService, klakiniCache, numberPairCache, store)
	savedNameHandler := handler.NewSavedNameHandler(savedNameService, store)

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

	// --- Routes ---

	// Landing Page
	app.Get("/", func(c *fiber.Ctx) error {
		return c.Render("landing", fiber.Map{
			"title":         "ยินดีต้อนรับ",
			"IsLoggedIn":    c.Locals("IsLoggedIn"),
			"toast_success": c.Locals("toast_success"),
			"toast_error":   c.Locals("toast_error"),
			"ActivePage":    "home",
		}, "layouts/main")
	})

	// Analyzer Page
	app.Get("/analyzer", func(c *fiber.Ctx) error {
		sampleNames, _ := sampleNamesCache.GetAll()

		// Get name and day from query parameters
		name := c.Query("name")
		day := c.Query("day")

		// Set default values if parameters are empty
		if name == "" {
			name = "อณัญญา"
		}
		if day == "" {
			day = "SUNDAY"
		}

		return c.Render("index", fiber.Map{
			"title":         "วิเคราะห์ชื่อ",
			"defaultName":   name,
			"defaultDay":    day,
			"sampleNames":   sampleNames,
			"IsLoggedIn":    c.Locals("IsLoggedIn"),
			"toast_success": c.Locals("toast_success"),
			"toast_error":   c.Locals("toast_error"),
			"ActivePage":    "analyzer",
		}, "layouts/main")
	})

	app.Get("/decode", numerologyHandler.Decode)
	app.Get("/solar-system", numerologyHandler.GetSolarSystem)
	app.Get("/similar-names-initial", numerologyHandler.GetSimilarNamesInitial)
	app.Get("/similar-names", numerologyHandler.GetSimilarNames)
	app.Get("/number-meanings", numerologyHandler.GetNumberMeanings)
	app.Get("/linguistic-analysis", numerologyHandler.AnalyzeLinguistically)

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
