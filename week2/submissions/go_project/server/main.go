package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
)

var port = "8080"
var db *sql.DB

// VolumeInfo is nested inside of Items
type VolumeInfo struct {
	Title     string   `json:"title"`
	Author    []string `json:"authors"`
	Publisher string   `json:"publisher"`
}

// Items is inside an object in an array
type Items struct {
	VolumeInfo VolumeInfo `json:"volumeInfo"`
}

// Books will hold all of the items we want.
type Books struct {
	Items []Items
}

func main() {
	// Getting environment variables that are secret
	err := godotenv.Load("week2.env")
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	// Connecting to the MySQL database
	pw := os.Getenv("MYSQL_PASSWORD")
	ds := fmt.Sprintf("jessica:%s@tcp(db:3306)/ita", pw)
	database, err := sql.Open("mysql", ds)
	if err != nil {
		panic(err)
	}
	fmt.Println("successfully connected to db")
	db = database
	defer db.Close()
	// Setting up a mux router
	router := mux.NewRouter()

	// Telling the server what to listen for and what to do
	router.HandleFunc("/api/author/{id}", getSingleAuthor)
	router.HandleFunc("/", homepage)
	//router.HandleFunc("/", getAuthor)

	// Creating the server
	fmt.Printf("listening on port %s\n", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		fmt.Println(err)
	}

}

// To parse out author from request
// func getAuthor() string {
// 	author := "Robert+Galbraith"
// 	return author
// }

func getSingleAuthor(w http.ResponseWriter, r *http.Request) {
	apiKey := os.Getenv("GBOOKS_API_KEY")
	author := parseAuthor(r)
	baseurl := fmt.Sprintf("https://www.googleapis.com/books/v1/volumes?key=%s&q=inauthor:%s", apiKey, author)
	// Getting response from the API
	resp, err := getJSON(baseurl)
	if err != nil {
		panic(err)
	}
	// Parsing the response
	books := parseJSON(resp)
	for _, v := range []string{"books", "authors", "publishers"} {
		a, err := db.Exec(insertBookData(books, v))
		if err != nil {
			fmt.Printf("Error: %e", err)
		}
		fmt.Println(a)
	}
	fmt.Println("single author api run")
}

// insertBooks will take in the Book and produce a query string that can be used to insert into database

// This will allow us to generate a hash based on whatever string is inserted
// In a db, it's more efficient to join on integers, and since we are creating 2 junction tables
// for author-book and publisher-book, you have to join to get any relational information.
// This is probably not the best way to do it, but it's a way to use integers to join instead of strings
func generateHash(s string) uint32 {
	h := fnv.New32a()
	h.Write([]byte(s))
	bs := h.Sum32()
	return bs
}

func insertBookData(b Books, table string) string {
	var name string
	var val string
	//var hash uint32
	var vs []string
	// // Depending on the table, the id has a different name
	//	dataArr := make(map[string]string)

	for _, s := range b.Items {
		switch {
		case table == "books":
			name = "title"
			val = s.VolumeInfo.Title
		case table == "authors":
			name = "author"
			val = strings.Join(s.VolumeInfo.Author, ", ")
		case table == "publishers":
			name = "publisher"
			val = s.VolumeInfo.Publisher
		}
		vs = append(vs, fmt.Sprintf("(\"%s\" , %v) ", val, generateHash(val)))
	}

	stmt, err := db.Prepare("INSERT IGNORE INTO ? (?, ?_id) values ?;")
	if err != nil {
		fmt.Println("hello")
		log.Fatal(err)
	}
	fmt.Println("db prepared")
	res, err := stmt.Exec(table, name, name, strings.Join(vs, ","))
	if err != nil {
		fmt.Println("hello world")
		log.Fatal(err)
	}
	rowCnt, err := res.RowsAffected()
	if err != nil {
		log.Fatal(err)
	}
	return fmt.Sprintf("%v new rows successfully added.", rowCnt)
}

// parseJson takes the byte slice of the JSON and returns a Book data type
// The Book holds a slice of all the books returned
func parseJSON(b []byte) Books {
	var books Books
	err := json.Unmarshal(b, &books)
	if err != nil {
		fmt.Println(err)
	} else {
		fmt.Println("no error")
	}

	return books
}

// To build request and return a byte slice that can be unmarshaled
func getJSON(url string) ([]byte, error) {
	// Running a get request for the passed URL. Panic if error.
	res, err := http.Get(url)
	if err != nil {
		fmt.Println(err)
		panic(err)
	}
	// Turning the response body into a byte slice so it can be used
	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err)
		panic(err)
	}
	// Turning byte slice body into string and return to be used with gjson parsing
	return body, nil
}

func parseAuthor(r *http.Request) string {
	s := fmt.Sprintf("%v", r.URL)
	s2 := strings.Split(s, "/")
	author := s2[len(s2)-1]
	return author
}

func homepage(w http.ResponseWriter, r *http.Request) {
	fmt.Println("homepage api run")
}

// // // getAllProducts sets the query for all products & runs getMultipleProducts to run the query
// // func getAllProducts(w http.ResponseWriter, r *http.Request) {
// // 	query := "SELECT Id, Name, Description, Price, Category FROM products"
// // 	getMultipleProducts(w, r, query)
// // 	fmt.Println("all product api run")
// // }

// // // getFeaturedProducts sets the query for featured products & runs getMultipleProducts to run the query
// // func getFeaturedProducts(w http.ResponseWriter, r *http.Request) {
// // 	query := "SELECT Id, Name, Description, Price, Category FROM products WHERE featured = 1"
// // 	getMultipleProducts(w, r, query)
// // 	fmt.Println("featured product api run")
// // }

// // // getSingleProduct queries and retrieves a single product from the database for the PDP
// // func getSingleProduct(w http.ResponseWriter, r *http.Request) {
// // 	setHeaders(w, r)
// // 	params := mux.Vars(r)
// // 	query := "SELECT Id, Name, Description, Price, Category, pic_1, pic_2, pic_3, pic_4 FROM products"
// // 	result, err := db.Query(query+" WHERE Id = ?", params["id"])
// // 	if err != nil {
// // 		fmt.Println(err)
// // 		return
// // 	}
// // 	defer result.Close()
// // 	// Taking all of the results & putting themt into a Product struct
// // 	for result.Next() {
// // 		var product Product
// // 		err := result.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category,
// // 			&product.Pic1, &product.Pic2, &product.Pic3, &product.Pic4)
// // 		if err != nil {
// // 			fmt.Println(err)
// // 			return
// // 		}
// // 		// Encoding the struct into JSON will allow us to access the JSON object using javascript
// // 		json.NewEncoder(w).Encode(product)
// // 		fmt.Println("single product api run")
// // 	}
// // }

// // getMultipleProducts queries & retrieves multiple products from the database
// func getMultipleProducts(w http.ResponseWriter, r *http.Request, query string) {
// 	setHeaders(w, r)
// 	// If it's a get request, we want to query and return the products
// 	if r.Method == http.MethodGet {
// 		products := []Product{}
// 		rows, err := db.Query(query)
// 		if err != nil {
// 			// Print error and return to leave the function
// 			fmt.Println(err)
// 			return
// 		}
// 		// Taking all of the results & putting themt into a Product struct
// 		// As long as there is a next row, we are defining which fields the product struct will be assigned
// 		for rows.Next() {
// 			var product Product
// 			err := rows.Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category)
// 			if err != nil {
// 				fmt.Println(err)
// 				return
// 			}
// 			// Appending all product structs to the products slice
// 			products = append(products, product)
// 		}
// 		// Encoding the struct into JSON will allow us to access the JSON object using javascript
// 		json.NewEncoder(w).Encode(products)
// 	}
// }

// setHeaders sets the headers for the response
func setHeaders(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "http://localhost:9090")
}
