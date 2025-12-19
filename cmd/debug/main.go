package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// Try to find .env file by walking up directories
	envPath := ".env"
	for i := 0; i < 3; i++ {
		if _, err := os.Stat(envPath); err == nil {
			break
		}
		envPath = filepath.Join("..", envPath)
	}

	// Load .env file
	if err := godotenv.Load(envPath); err != nil {
		log.Fatalf("Error loading .env file from %s: %v", envPath, err)
	}
	fmt.Printf("Loaded .env from %s\n", envPath)

	// Connect to database
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))

	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Check connection
	err = db.Ping()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Successfully connected to database!")

	// Count rows in names_miracle
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM names_miracle").Scan(&count)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Total rows in names_miracle: %d\n", count)

	// Fetch first 5 rows
	rows, err := db.Query("SELECT name_id, thname, satnum, shanum FROM names_miracle LIMIT 5")
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	fmt.Println("First 5 rows:")
	for rows.Next() {
		var id int
		var name string
		var sat, sha string
		if err := rows.Scan(&id, &name, &sat, &sha); err != nil {
			log.Fatal(err)
		}
		fmt.Printf("ID: %d, Name: %s, Sat: %s, Sha: %s\n", id, name, sat, sha)
	}
}
