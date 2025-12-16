package main

import (
	"database/sql"
	"fmt"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler"
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/ports"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// --- Initialization ---
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	db := setupDatabase()
	defer db.Close()

	// Setup all three caches
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)

	// --- Setup Fiber App & Handlers ---
	app := fiber.New()

	// Create the handler and inject all dependencies
	numerologyHandler := handler.NewNumerologyHandler(numerologyCache, shadowCache, klakiniCache)

	// Register the route to the handler method
	app.Get("/decode", numerologyHandler.Decode)

	// --- Start Server ---
	log.Println("Starting server on port 3000...")
	log.Fatal(app.Listen(":3000"))
}

func setupDatabase() *sql.DB {
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
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

// setupNumerologyCache is a generic function to set up a cache for a given table.
func setupNumerologyCache(db *sql.DB, tableName string) *cache.NumerologyCache {
	var repo ports.NumerologyRepository = repository.NewPostgresNumerologyRepository(db, tableName)
	c := cache.NewNumerologyCache(repo)

	fmt.Printf("Warming up the cache for table '%s'...\n", tableName)
	// Correctly handle the two return values from GetAll
	if _, err := c.GetAll(); err != nil {
		log.Fatalf("Failed to warm up cache for table '%s': %v", tableName, err)
	}
	fmt.Printf("Cache for table '%s' is ready.\n", tableName)
	return c
}

// setupKlakiniCache initializes and returns the Klakini cache.
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
