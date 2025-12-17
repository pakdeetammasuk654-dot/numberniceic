package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler"
	"numberniceic/internal/adapters/repository"
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

// Struct to hold sample names from JSON
type SampleNamesConfig struct {
	SampleNames []string `json:"sampleNames"`
}

func loadSampleNames() []handler.SampleName {
	var config SampleNamesConfig
	var sampleNames []handler.SampleName

	// Read the JSON file
	file, err := ioutil.ReadFile("config/samples.json")
	if err != nil {
		log.Printf("Warning: Could not read config/samples.json: %v", err)
		return sampleNames // Return empty list on error
	}

	// Parse the JSON
	err = json.Unmarshal(file, &config)
	if err != nil {
		log.Printf("Warning: Could not parse config/samples.json: %v", err)
		return sampleNames // Return empty list on error
	}

	// Create the final list with Avatar URLs
	for i, name := range config.SampleNames {
		sampleNames = append(sampleNames, handler.SampleName{
			Name:      name,
			AvatarURL: fmt.Sprintf("https://i.pravatar.cc/100?img=%d", i+1),
		})
	}
	return sampleNames
}

func main() {
	// --- Initialization ---
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	engine := html.New("./views", ".html")
	engine.Reload(true)

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

	// Setup components
	numerologyCache := setupNumerologyCache(db, "sat_nums")
	shadowCache := setupNumerologyCache(db, "sha_nums")
	klakiniCache := setupKlakiniCache(db)
	numberPairCache := setupNumberPairCache(db)
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
	)

	// --- Routes ---
	app.Get("/", func(c *fiber.Ctx) error {
		// Load sample names from JSON file
		sampleNames := loadSampleNames()

		return c.Render("index", fiber.Map{
			"title":       "หน้าหลัก",
			"defaultName": "อณัญญา",
			"defaultDay":  "SUNDAY",
			"sampleNames": sampleNames,
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
