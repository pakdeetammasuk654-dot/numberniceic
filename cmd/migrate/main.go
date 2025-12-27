package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	forceVersion := flag.Int("force", -1, "Force set migration version (use with caution)")
	flag.Parse()

	// Load .env file
	// Try loading from current dir or parent dirs if running from cmd/migrate
	if err := godotenv.Load(); err != nil {
		if err := godotenv.Load("../../.env"); err != nil {
			log.Println("Warning: No .env file found, relying on environment variables.")
		} else {
			log.Println("Loaded .env file from ../../.env")
		}
	} else {
		log.Println("Loaded .env file.")
	}

	// DB Config
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")

	if host == "" {
		host = "localhost"
	}
	if port == "" {
		port = "5432"
	}

	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	fmt.Printf("Connecting to DB: %s@%s:%s/%s\n", user, host, port, dbname)

	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatalf("Failed to open DB connection: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping DB: %v", err)
	}

	driver, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		log.Fatalf("Failed to create driver: %v", err)
	}

	// Adjust migration path based on execution context
	migrationPath := "file://migrations"
	if _, err := os.Stat("migrations"); os.IsNotExist(err) {
		if _, err := os.Stat("../../migrations"); err == nil {
			migrationPath = "file://../../migrations"
		}
	}

	m, err := migrate.NewWithDatabaseInstance(
		migrationPath,
		"postgres", driver)
	if err != nil {
		log.Fatalf("Failed to create migrate instance: %v", err)
	}

	// Handle Force Version
	if *forceVersion >= 0 {
		log.Printf("Forcing migration version to %d...", *forceVersion)
		if err := m.Force(*forceVersion); err != nil {
			log.Fatalf("Failed to force version: %v", err)
		}
		log.Println("Force version successful. Please run migration again without -force flag.")
		return
	}

	log.Println("Running migrations...")
	if err := m.Up(); err != nil {
		if err == migrate.ErrNoChange {
			log.Println("No changes to apply.")
		} else {
			log.Fatalf("Migration failed: %v", err)
		}
	} else {
		log.Println("Migration successful!")
	}
}
