package config

import (
	"os"
)

type Config struct {
	ViteURL   string
	ViteEntry string
	DistDir   string
	AssetsDir string
}

func New() *Config {
	return &Config{
		ViteURL:   getEnv("VITE_URL", "http://localhost:5174"),
		ViteEntry: getEnv("VITE_ENTRY", "src/main.ts"),
		DistDir:   getEnv("DIST_DIR", "dist"),
		AssetsDir: getEnv("ASSETS_DIR", "./src/assets"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
