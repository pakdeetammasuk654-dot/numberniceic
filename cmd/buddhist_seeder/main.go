package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// Try to load .env from root (assuming running from root or cmd/buddhist_seeder)
	envPath := ".env"
	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		// try 2 levels up
		envPath = "../../.env"
	}
	if err := godotenv.Load(envPath); err != nil {
		log.Println("Warning: .env file not found, relying on environment variables.")
	}

	// Connect to DB
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
	)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	fmt.Println("Connected to database successfully.")
	seedBuddhistDays(db)
}

func seedBuddhistDays(db *sql.DB) {
	// Synodic Month (Mean)
	const synodicMonth = 29.530589

	// Base New Moon (Reference): Jan 11, 2024 at 11:57 UTC
	// This is scientifically accurate for the first New Moon of 2024.
	baseNewMoon := time.Date(2024, 1, 11, 11, 57, 0, 0, time.UTC)

	// Target Range: 2024 - 2030
	startDate := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2030, 12, 31, 23, 59, 59, 0, time.UTC)

	// Bangkok Location
	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		// Fallback to Fixed Zone +7 if system timezone loading fails (e.g. minimal docker container)
		loc = time.FixedZone("ICT", 7*60*60)
	}

	totalInserted := 0
	totalSkipped := 0

	// Helper for duration from days
	daysToDuration := func(days float64) time.Duration {
		return time.Duration(days * 24 * float64(time.Hour))
	}

	// We calculate cycles.
	// Start from a bit earlier (e.g. -2 cycles) to ensure we cover Jan 1st 2024 correctly if needed (e.g. previous moon ending)
	// 2030 is about 6 years. 6 * 12.3 cycles ~ 74 cycles. Let's do 100 cycles to be safe.
	for i := -2; i < 90; i++ {
		// Time of New Moon for this cycle
		daysToAdd := float64(i) * synodicMonth
		cycleNewMoon := baseNewMoon.Add(daysToDuration(daysToAdd))

		// Phases:
		// 1. Waxing 8 (Quarter): ~ New Moon + 7.38 days
		waxing8Time := cycleNewMoon.Add(daysToDuration(7.382647))
		processDate(db, waxing8Time, loc, startDate, endDate, &totalInserted, &totalSkipped)

		// 2. Full Moon (Waxing 15): ~ New Moon + 14.765 days
		fullMoonTime := cycleNewMoon.Add(daysToDuration(14.765294))
		processDate(db, fullMoonTime, loc, startDate, endDate, &totalInserted, &totalSkipped)

		// 3. Waning 8 (Last Quarter): ~ New Moon + 22.148 days
		waning8Time := cycleNewMoon.Add(daysToDuration(22.147941))
		processDate(db, waning8Time, loc, startDate, endDate, &totalInserted, &totalSkipped)

		// 4. Waning 14/15 (Day before NEXT New Moon): ~ Next New Moon - 1 day (Roughly)
		// Precise calculation: Next New Moon Time
		nextNewMoonTime := cycleNewMoon.Add(daysToDuration(synodicMonth))
		// The custom is usually the day BEFORE the New Moon conjunction.
		waningEndMonthTime := nextNewMoonTime.Add(-24 * time.Hour)
		processDate(db, waningEndMonthTime, loc, startDate, endDate, &totalInserted, &totalSkipped)
	}

	fmt.Printf("Seeding Complete.\nInserted: %d\nSkipped (Existing): %d\n", totalInserted, totalSkipped)
}

func processDate(db *sql.DB, t time.Time, loc *time.Location, start, end time.Time, inserted, skipped *int) {
	// Convert astronomical time to Bangkok Date
	localTime := t.In(loc)
	dateOnly := time.Date(localTime.Year(), localTime.Month(), localTime.Day(), 0, 0, 0, 0, loc)

	if dateOnly.Before(start) || dateOnly.After(end) {
		return
	}

	// Check existence
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM buddhist_days WHERE date = $1", dateOnly).Scan(&count)
	if err != nil {
		log.Printf("Error checking date %s: %v", dateOnly, err)
		return
	}

	if count > 0 {
		*skipped++
		return
	}

	// Insert
	_, err = db.Exec("INSERT INTO buddhist_days (date) VALUES ($1)", dateOnly)
	if err != nil {
		log.Printf("Error inserting date %s: %v", dateOnly, err)
		return
	}
	*inserted++
	// fmt.Printf("Added: %s\n", dateOnly.Format("2006-01-02"))
}
