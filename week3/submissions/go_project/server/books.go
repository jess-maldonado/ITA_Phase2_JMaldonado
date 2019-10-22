// TO DO: FIGURE OUT JUNCTION TABLE

package main

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"
)

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

func getAuthors(w http.ResponseWriter, r *http.Request) {
	setHeaders(w, r, host)
	apiKey := os.Getenv("GBOOKS_API_KEY")
	author := parseAuthor(r)
	for _, n := range author {
		go func(n string) {
			getSingleAuthor(apiKey, n)
		}(n)
	}
}

func getSingleAuthor(apiKey string, author string) {
	baseurl := fmt.Sprintf("https://www.googleapis.com/books/v1/volumes?key=%s&q=inauthor:%s", apiKey, author)
	// Getting response from the API
	resp, err := getJSON(baseurl)
	if err != nil {
		panic(err)
	}
	// Parsing the response
	books := parseJSON(resp)
	tables := []string{"books", "authors", "publishers"}
	for _, v := range tables {
		qsCreate, qsInsert, _ := books.insertBookData(v)
		// Creating tables if they don't exist - this will stop us from getting tables don't exist error.
		r, err := runQueries(qsCreate, qsInsert)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(fmt.Sprintf("%v new rows inserted into table %s for author %s .", r, v, author))
	}

	for _, v := range []string{"publisher", "author"} {
		qsCreate, qsInsert := insertJunctionData(books, v)
		r, err := runQueries(qsCreate, qsInsert)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(fmt.Sprintf("%v new rows inserted into table books_%ss.", r, v))

	}
}

func runQueries(qsCreate string, qsInsert string) (int64, error) {
	a, err := db.Exec(qsCreate)
	if err != nil {
		fmt.Printf("Error: %e", err)
	}
	// Running the insert statement
	a, err = db.Exec(qsInsert)
	if err != nil {
		fmt.Printf("Error: %e", err)
	}
	r, err := a.RowsAffected()
	return r, err
}

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

// insertBooks will take in the Book and produce a query string that can be used to insert into database
func (b Books) insertBookData(table string) (string, string, map[string][]uint32) {
	var name string
	var val string
	//var hash uint32
	var vs []string
	junctionMap := make(map[string][]uint32)
	var junctionVal []uint32
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
		junctionVal = append(junctionVal, generateHash(val))
		junctionMap[name] = junctionVal
	}

	// Query string
	qsInsert := fmt.Sprintf("INSERT IGNORE INTO %s (%s, %s_id) values %s;", table, name, name, strings.Join(vs, ","))
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (%s_id BIGINT,%s VARCHAR(255),PRIMARY KEY (%s_id));", table, name, name, name)
	return qsCreate, qsInsert, junctionMap
}

func insertJunctionData(b Books, t string) (string, string) {
	_, _, titles := b.insertBookData("books")
	q := t + "s"
	// getting the map for the given string
	_, _, junction := b.insertBookData(q)
	// Create table if not exists so there are no 'table does not exist' errors
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS books_%ss (title_id BIGINT, %s_id VARCHAR(255), PRIMARY KEY (title_id, %s_id));", t, t, t)
	// Creating the string of two IDs in separate maps that will be used in the query string
	var booksJunction []string
	for i, v := range titles["title"] {
		booksJunction = append(booksJunction, fmt.Sprintf("(%v, %v)", v, junction[t][i]))
	}

	qsInsert := fmt.Sprintf("INSERT IGNORE INTO books_%ss (title_id, %s_id) values %s;", t, t, strings.Join(booksJunction, " , "))

	return qsCreate, qsInsert
}

// parseJson takes the byte slice of the JSON and returns a Book data type
// The Book holds a slice of all the books returned
func parseJSON(b []byte) Books {
	var books Books
	err := json.Unmarshal(b, &books)
	if err != nil {
		log.Fatal(err)
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

func parseAuthor(r *http.Request) []string {
	s := fmt.Sprintf("%v", r.URL)
	s2 := strings.Split(s, "/")
	authors := strings.Split(s2[len(s2)-1], "&")
	return authors
}
