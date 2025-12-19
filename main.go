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

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"
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
	// Use Overload to force overwrite existing environment variables with values from .env
	// This fixes issues where an old/invalid key might be cached in the terminal session.
	err := godotenv.Overload()
	if err != nil {
		log.Printf("Warning: Error loading .env file (this is fine in production if env vars are set): %v", err)
	} else {
		log.Println("Successfully loaded (overloaded) .env file.")
	}

	apiKey := os.Getenv("GEMINI_API_KEY")

	// Debug log to verify the key is loaded (masked for security)
	if apiKey == "" {
		log.Println("CRITICAL WARNING: GEMINI_API_KEY is empty! The linguistic service will fail.")
	} else {
		maskedKey := apiKey
		if len(apiKey) > 8 {
			maskedKey = apiKey[:4] + "..." + apiKey[len(apiKey)-4:]
		}
		log.Printf("Loaded GEMINI_API_KEY: %s (Length: %d)", maskedKey, len(apiKey))
	}

	// Create a new engine for each request in development to ensure templates are reloaded.
	engine := html.New("./views", ".html")
	engine.Reload(true) // This should be enough, but we'll be extra sure.
	// engine.Debug(true) // This is verbose and logs every template parse.

	engine.AddFunc("mul", func(a, b interface{}) (float64, error) {
		fa, errA := toFloat64(a)
		fb, errB := toFloat64(b)
		if errA != nil || errB != nil {
			return 0, fmt.Errorf("mul error")
		}
		return fa * fb, nil
	})
	engine.AddFunc("div", func(a, b interface{}) (float64, error) {
		fa, errA := toFloat64(a)
		fb, errB := toFloat64(b)
		if errA != nil || errB != nil {
			return 0, fmt.Errorf("div error")
		}
		if fb == 0 {
			return 0, nil
		}
		return fa / fb, nil
	})
	engine.AddFunc("add", func(a, b interface{}) (float64, error) {
		fa, errA := toFloat64(a)
		fb, errB := toFloat64(b)
		if errA != nil || errB != nil {
			return 0, fmt.Errorf("add error")
		}
		return fa + fb, nil
	})
	engine.AddFunc("mod", func(a, b int) int {
		return a % b
	})
	engine.AddFunc("printf", fmt.Sprintf)
	engine.AddFunc("substr", func(s string, start, length int) string {
		asRunes := []rune(s)
		if start >= len(asRunes) {
			return ""
		}
		if start+length > len(asRunes) {
			length = len(asRunes) - start
		}
		return string(asRunes[start : start+length])
	})
	engine.AddFunc("HTML", func(s string) template.HTML {
		return template.HTML(s)
	})

	db := setupDatabase()
	defer db.Close()

	// Setup services
	linguisticService, err := service.NewLinguisticService(apiKey)
	if err != nil {
		log.Printf("Failed to create linguistic service: %v", err)
	}

	// Setup components
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)
	numberPairCache := setupNumberPairCache(db)
	sampleNamesCache := setupSampleNamesCache(db)
	namesMiracleRepo := repository.NewPostgresNamesMiracleRepository(db)

	// --- Setup Fiber App ---
	app := fiber.New(fiber.Config{
		Views: engine,
	})

	app.Use(recover.New())
	app.Static("/", "./static")

	numerologyHandler := handler.NewNumerologyHandler(
		numerologyCache,
		shadowCache,
		klakiniCache,
		numberPairCache,
		namesMiracleRepo,
		linguisticService,
	)

	// --- Routes ---
	app.Get("/", func(c *fiber.Ctx) error {
		sampleNames, err := sampleNamesCache.GetAll()
		if err != nil {
			log.Printf("Warning: Could not load sample names from cache: %v", err)
		}

		return c.Render("index", fiber.Map{
			"title":       "หน้าหลัก",
			"defaultName": "อณัญญา",
			"defaultDay":  "SUNDAY",
			"sampleNames": sampleNames,
		}, "main")
	})

	app.Get("/decode", numerologyHandler.Decode)
	app.Get("/solar-system", numerologyHandler.GetSolarSystem)
	app.Get("/similar-names-initial", numerologyHandler.GetSimilarNamesInitial)
	app.Get("/similar-names", numerologyHandler.GetSimilarNames)
	app.Get("/auspicious-names", numerologyHandler.GetAuspiciousNames)
	app.Get("/number-meanings", numerologyHandler.GetNumberMeanings)
	app.Get("/linguistic-analysis", numerologyHandler.AnalyzeLinguistically)

	// --- Start Server ---
	log.Println("Starting server on port 3000...")
	log.Fatal(app.Listen(":3000"))
}

// ... (setup functions remain the same) ...
func setupDatabase() *sql.DB {
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable client_encoding=UTF8",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))
	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	if err = db.Ping(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	fmt.Println("Successfully connected to database!")
	return db
}

func setupNumerologyCache(db *sql.DB, tableName string) *cache.NumerologyCache {
	repo := repository.NewPostgresNumerologyRepository(db, tableName)
	c := cache.NewNumerologyCache(repo)
	fmt.Printf("Warming up the cache for table '%s'...\n", tableName)
	if _, err := c.GetAll(); err != nil {
		log.Fatalf("Failed to warm up cache for table '%s': %v", tableName, err)
	}
	fmt.Printf("Cache for table '%s' is ready.\n", tableName)
	return c
}

func setupKlakiniCache(db *sql.DB) *cache.KlakiniCache {
	repo := repository.NewPostgresKlakiniRepository(db)
	c := cache.NewKlakiniCache(repo)
	fmt.Println("Warming up the klakini cache...")
	if err := c.EnsureLoaded(); err != nil {
		log.Fatalf("Failed to warm up klakini cache: %v", err)
	}
	fmt.Println("Klakini cache is ready.")
	return c
}

func setupNumberPairCache(db *sql.DB) *cache.NumberPairCache {
	repo := repository.NewPostgresNumberPairRepository(db)
	c := cache.NewNumberPairCache(repo)
	fmt.Println("Warming up the number pair meaning cache...")
	if err := c.EnsureLoaded(); err != nil {
		log.Fatalf("Failed to warm up number pair meaning cache: %v", err)
	}
	fmt.Println("Number pair meaning cache is ready.")
	return c
}

func setupSampleNamesCache(db *sql.DB) *cache.SampleNamesCache {
	repo := repository.NewPostgresSampleNamesRepository(db)
	c := cache.NewSampleNamesCache(repo)
	fmt.Println("Warming up the sample names cache...")
	if err := c.EnsureLoaded(); err != nil {
		log.Fatalf("Failed to warm up sample names cache: %v", err)
	}
	fmt.Println("Sample names cache is ready.")
	return c
}
