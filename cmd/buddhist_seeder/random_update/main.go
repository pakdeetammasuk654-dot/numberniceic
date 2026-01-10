package main

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

var messages = []string{
	"ธรรมะสวัสดี วันพระนี้ขอให้มีแต่ความสุขกาย สบายใจ",
	"วันนี้วันพระ ขอพระคุ้มครอง วิถีแห่งบุญนำพาความสุขมาให้",
	"สะสมบุญวันละนิด จิตใจผ่องใส ขอให้เป็นวันพระที่เปี่ยมด้วยสติ",
	"แสงเทียนสว่างที่กลางใจ ขอให้บุญรักษาในวันพระนี้",
	"วันนี้วันพระ ตั้งจิตให้มั่น ทำดีให้ถึงพร้อมเพื่อความสงบสุข",
	"บุญระลึก กุศลนำพา ขอให้วันพระนี้เป็นวันที่ดีสำหรับคุณ",
	"ธรรมะคือทางสว่าง ขอให้ทุกท่านมีความสุขสงบในวันมงคลนี้",
	"วันนี้วันพระ ขอให้คุณพระศรีรัตนตรัยคุ้มครองให้ร่มเย็นเป็นสุข",
	"ยิ้มรับบุญในวันพระ ขอให้พบเจอแต่สิ่งดีงามและกัลยาณมิตร",
	"จิตที่ฝึกดีแล้วนำสุขมาให้ ขอให้วันพระนี้เป็นวันที่จิตใจผ่องแผ้ว",
}

func main() {
	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: No .env file found, relying on environment variables.")
	}

	// DB Config from environment
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

	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}
	defer db.Close()

	rows, err := db.Query("SELECT id FROM buddhist_days")
	if err != nil {
		log.Fatalf("Failed to query days: %v", err)
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			log.Fatal(err)
		}
		ids = append(ids, id)
	}

	rand.Seed(time.Now().UnixNano())

	fmt.Printf("Updating %d buddhist day messages...\n", len(ids))

	tx, err := db.Begin()
	if err != nil {
		log.Fatal(err)
	}

	stmt, err := tx.Prepare("UPDATE buddhist_days SET message = $1 WHERE id = $2")
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()

	for _, id := range ids {
		msg := messages[rand.Intn(len(messages))]
		_, err := stmt.Exec(msg, id)
		if err != nil {
			tx.Rollback()
			log.Fatal(err)
		}
	}

	err = tx.Commit()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Successfully updated all buddhist day messages with random Dhamma greetings!")
}
