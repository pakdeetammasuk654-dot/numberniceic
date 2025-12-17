package main

import (
	"database/sql"
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler"
	"numberniceic/internal/adapters/repository"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/template/html/v2"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// --- Initialization ---
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	engine := html.New("./views", ".html")
	engine.Reload(true)

	db := setupDatabase()
	defer db.Close()

	// Setup caches
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)
	numberPairCache := setupNumberPairCache(db)

	// Setup repositories
	namesMiracleRepo := repository.NewPostgresNamesMiracleRepository(db)

	// --- Setup Fiber App ---
	app := fiber.New(fiber.Config{
		Views: engine,
	})

	app.Use(recover.New())

	// Serve static files (CSS, JS, images)
	app.Static("/", "./static")

	// Create the handler
	numerologyHandler := handler.NewNumerologyHandler(
		numerologyCache,
		shadowCache,
		klakiniCache,
		numberPairCache,
		namesMiracleRepo,
	)

	// --- Routes ---
	app.Get("/", func(c *fiber.Ctx) error {
		return c.Render("index", fiber.Map{
			"title": "หน้าหลัก",
		}, "main")
	})

	app.Get("/decode", numerologyHandler.Decode)
	app.Get("/similar-names", numerologyHandler.GetSimilarNames)
	app.Get("/auspicious-names", numerologyHandler.GetAuspiciousNames)

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
