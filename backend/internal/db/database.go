package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

var DB *sql.DB

// initializes the connection to postgresql
func Connect() {
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: No .env file found. Relying on system environment variables")
	}

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
	)

	var err error
	DB, err = sql.Open("pgx", dsn)
	if err != nil {
		log.Fatalf("Fatal error opening database: %v\n", err)
	}

	// test the connection
	for i := 0; i < 5; i++ {
		err = DB.Ping()
		if err == nil {
			log.Println("Successfully connected to the PostgreSQL database!")
			return
		}
		log.Printf("Database not ready yet... retrying (%d/5)\n", i+1)
		time.Sleep(2 * time.Second)
	}

	log.Fatalf("Could not connect to database after retries: %v\n", err)
}

func Close() {
	if DB != nil {
		DB.Close()
	}
}
