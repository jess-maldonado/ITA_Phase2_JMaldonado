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

// getAuthors will run the getSingleAuthor function for every author (for when there are multiple authors)
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
		log.Fatal(err)
	}
	// Parsing the response
	books := parseJSON(resp)
	var qsCreateBook, qsBookInsert, qsCreateAuthor, qsAuthorInsert, qsCreatePub, qsPubInsert string
	junctionID := make(map[string][]uint32)

	// Generating queries & adding to the map
	qsCreateBook, qsBookInsert, junctionID["title"] = books.generateBookQueries()
	qsCreateAuthor, qsAuthorInsert, junctionID["author"] = books.generateAuthorQueries()
	qsCreatePub, qsPubInsert, junctionID["publisher"] = books.generatePublisherQueries()

	// Running book queries & printing error or success
	r, err := runQueries(qsCreateBook, qsBookInsert)
	if err != nil {
		log.Println(err)
	}
	fmt.Println(fmt.Sprintf("%v new rows inserted into table books for author %s .", r, author))

	// Running author queries & printing error or success
	r, err = runQueries(qsCreateAuthor, qsAuthorInsert)
	if err != nil {
		log.Println(err)
	}
	fmt.Println(fmt.Sprintf("%v new rows inserted into table authors for author %s .", r, author))

	// Running publisher queries & printing error or success
	r, err = runQueries(qsCreatePub, qsPubInsert)
	if err != nil {
		log.Println(err)
	}
	fmt.Println(fmt.Sprintf("%v new rows inserted into table publishers for author %s .", r, author))

	// Running insert junction table queries
	for _, v := range [2]string{"publisher", "author"} {
		qsCreate, qsInsert := insertJunctionData(v, junctionID)
		r, err := runQueries(qsCreate, qsInsert)
		if err != nil {
			log.Println(err)
		}
		fmt.Println(fmt.Sprintf("%v new rows inserted into table books_%ss.", r, v))

	}
}

// Executing the queries - create if not exists first, and then inserting. Returns rows affected.
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

// generateBookQueries creates the necessary queries for populating the books table
func (b Books) generateBookQueries() (string, string, []uint32) {
	var vs []string
	var titleHashes []uint32
	name := "title"
	for _, s := range b.Items {
		val := s.VolumeInfo.Title
		vs = append(vs, fmt.Sprintf("(\"%s\" , %v) ", val, generateHash(val)))
		titleHashes = append(titleHashes, generateHash(val))
	}

	qsInsert := fmt.Sprintf("INSERT IGNORE INTO books (%s, %s_id) values %s;", name, name, strings.Join(vs, ","))
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS books (%s_id BIGINT,%s VARCHAR(255),PRIMARY KEY (%s_id));", name, name, name)
	return qsCreate, qsInsert, titleHashes
}

// generateAuthorQueries creates the necessary queries for populating the author table
func (b Books) generateAuthorQueries() (string, string, []uint32) {
	var vs []string
	var authorHashes []uint32
	name := "author"
	for _, s := range b.Items {
		val := strings.Join(s.VolumeInfo.Author, ", ")
		vs = append(vs, fmt.Sprintf("(\"%s\" , %v) ", val, generateHash(val)))
		authorHashes = append(authorHashes, generateHash(val))
	}

	qsInsert := fmt.Sprintf("INSERT IGNORE INTO authors (%s, %s_id) values %s;", name, name, strings.Join(vs, ","))
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS authors (%s_id BIGINT,%s VARCHAR(255),PRIMARY KEY (%s_id));", name, name, name)
	return qsCreate, qsInsert, authorHashes

}

// generatePublisherQueries creates the necessary queries for populating the publisher table
func (b Books) generatePublisherQueries() (string, string, []uint32) {
	var vs []string
	var pubHashes []uint32
	name := "publisher"
	for _, s := range b.Items {
		val := s.VolumeInfo.Publisher
		vs = append(vs, fmt.Sprintf("(\"%s\" , %v) ", val, generateHash(val)))
		pubHashes = append(pubHashes, generateHash(val))
	}

	qsInsert := fmt.Sprintf("INSERT IGNORE INTO publishers (%s, %s_id) values %s;", name, name, strings.Join(vs, ","))
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS publishers (%s_id BIGINT,%s VARCHAR(255),PRIMARY KEY (%s_id));", name, name, name)
	return qsCreate, qsInsert, pubHashes
}

// func insertJunctionData(b Books, t string) (string, string) {
// 	// Getting all of the title data because both author & publisher will need to tie to books
// 	_, _, titles := b.insertBookData("books")
// 	q := t + "s"
// 	// getting the map for the given string (author or publisher)
// 	_, _, junction := b.insertBookData(q)
// 	// Create table if not exists so there are no 'table does not exist' errors
// 	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS books_%ss (title_id BIGINT, %s_id VARCHAR(255), PRIMARY KEY (title_id, %s_id));", t, t, t)
// 	// Creating the string of two IDs in separate maps that will be used in the query string
// 	var booksJunction []string
// 	for i, v := range titles["title"] {
// 		// value of map key "title" is the hash created; the junction[t][i] represents the hash value created for the author or publisher
// 		booksJunction = append(booksJunction, fmt.Sprintf("(%v, %v)", v, junction[t][i]))
// 	}
// 	qsInsert := fmt.Sprintf("INSERT IGNORE INTO books_%ss (title_id, %s_id) values %s;", t, t, strings.Join(booksJunction, " , "))

// 	return qsCreate, qsInsert
// }

func insertJunctionData(other string, m map[string][]uint32) (string, string) {
	var booksJunction []string
	for i, v := range m["title"] {
		booksJunction = append(booksJunction, fmt.Sprintf("(%v, %v)", v, m[other][i]))
	}
	qsCreate := fmt.Sprintf("CREATE TABLE IF NOT EXISTS books_%ss (title_id BIGINT, %s_id VARCHAR(255), PRIMARY KEY (title_id, %s_id));", other, other, other)
	qsInsert := fmt.Sprintf("INSERT IGNORE INTO books_%ss (title_id, %s_id) values %s;", other, other, strings.Join(booksJunction, " , "))

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
	}
	// Turning the response body into a byte slice so it can be used
	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err)
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
