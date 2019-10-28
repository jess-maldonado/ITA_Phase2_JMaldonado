package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
)

var port = "8080"
var db *sql.DB
var host string
var clientHost string

func main() {
	// Getting environment variables that are secret
	host = "localhost:8080"
	clientHost = "localhost:8000"

	err := godotenv.Load("week2.env")
	if err != nil {
		log.Fatal("Error loading .env file")
	}
	// Connecting to the MySQL database
	pw, _ := os.LookupEnv("MYSQL_ROOT_PASSWORD")
	user, _ := os.LookupEnv("MYSQL_USER")
	ds := fmt.Sprintf("%s:%s@tcp(db:3306)/google_books", user, pw)
	database, err := sql.Open("mysql", ds)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("successfully connected to db")
	db = database
	defer db.Close()
	// Setting up a mux router
	router := mux.NewRouter()

	// Telling the server what to listen for and what to do
	router.HandleFunc("/api/author/{id}", getAuthors).Methods("POST", "OPTIONS")

	// Creating the server
	fmt.Printf("listening on port %s\n", port)
	err = http.ListenAndServe(":"+port, router)
	if err != nil {
		fmt.Println(err)
	}
}

// setHeaders sets the headers for the response
func setHeaders(w http.ResponseWriter, r *http.Request, host string) {
	w.Header().Set("Access-Control-Allow-Origin", fmt.Sprintf("http://%s", clientHost))
	w.Header().Set("Content-Type", "application/json")
}
