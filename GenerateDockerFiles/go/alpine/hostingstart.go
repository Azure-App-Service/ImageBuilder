package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8000"
    }
    http.HandleFunc("/", handler)
    http.ListenAndServe(fmt.Sprintf(":%s", port), nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
    http.ServeFile(w, r, "/opt/startup/hostingstart.html")
}