package main

import (
	"fmt"
	"os"

	"zapuskalka-backend/internal/app"
	"zapuskalka-backend/internal/config"

	_ "zapuskalka-backend/migrations"
)

func main() {
	// TODO: Заменить на dotenv
	cfg := config.New()

	pb := app.New(cfg)

	if err := pb.Start(); err != nil {
		fmt.Println("Error starting application:", err)
		os.Exit(1)
	}
}
