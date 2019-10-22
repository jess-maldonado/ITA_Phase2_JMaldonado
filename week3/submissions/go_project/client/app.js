// function submitAuthor() {
//     let author = document.getElementById("author").value;
//     // Parsing the author string into an array and then back into a string separated by "+" instead of a space
//     let authString = author.split(" ").join("+");
//     console.log(authString)
//     // The endpoint we are going to hit
//     let url = "http://localhost:8080/api/author/"+authString;
//     console.log(url)
//     // Creating and sending the http request
//     let xhttp = new XMLHttpRequest();
//     xhttp.open("POST",url, true);
//     xhttp.send();


// }

function submitAuthor() {
    let author = document.getElementById("author").value;
    // Parsing the author string into an array and then back into a string separated by "+" instead of a space
    let authSplit = author.split(",");
    console.log(authSplit)
    let authString = [];
    for (i = 0; i < authSplit.length; i++) {
        authString.push(authSplit[i].trim().split(" ").join("+"));
        console.log(authString);
    }
    let authors = authString.join("&");
    console.log(authors)
    // The endpoint we are going to hit
    let url = "http://localhost:8080/api/author/"+authors;
    // Creating and sending the http request
    let xhttp = new XMLHttpRequest();
    xhttp.open("POST",url, true);
    xhttp.send();


}