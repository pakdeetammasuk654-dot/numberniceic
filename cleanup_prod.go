package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// 1. Force load .env.production to target the REAL server DB
	if err := godotenv.Overload(".env.production"); err != nil {
		log.Println("Note: .env.production not found")
	}

	// 2. Connect
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable client_encoding=UTF8",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))

	fmt.Printf("Connecting to PROD DB: %s @ %s ...\n", os.Getenv("DB_NAME"), os.Getenv("DB_HOST"))

	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatalf("Err: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("Err ping: %v", err)
	}
	fmt.Println("Connected to PROD successfully.")

	// 3. Delete SPAM
	// Strategy: Delete ANY notification with title containing "สีกระเป๋า"
	// because these are the ones involved in the loop.
	// AND verify it's the right table.

	query := "DELETE FROM user_notifications WHERE title LIKE '%สีกระเป๋า%'"
	res, err := db.Exec(query)
	if err != nil {
		log.Fatalf("Delete error: %v", err)
	}
	rows, _ := res.RowsAffected()
	fmt.Printf("🔥 DELETED %d SPAM NOTIFICATIONS FROM PRODUCTION 🔥\n", rows)
}
