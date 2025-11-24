package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

// App struct
type App struct {
	ctx context.Context
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// Greet returns a greeting for the given name
func (a *App) Greet(name string) string {
	return fmt.Sprintf("Hello %s, It's show time!", name)
}

func (a *App) RunGame(gameId string) {
	log.Println("EXECUTING GAME: " + gameId)
}

func (a *App) OsOpenFolder() string {
	path, err := runtime.OpenDirectoryDialog(a.ctx, runtime.OpenDialogOptions{})
	if err != nil {
		log.Println(err)
		return ""
	}

	return path
}

type Storage struct {
	Title string   `json:"title"`
	Path  string   `json:"path"`
}

func (a *App) SaveStorageList(storageList []Storage) {
	dir, err := os.UserConfigDir()
	if err != nil {
		log.Println(err)
		return
	}

	appDir := filepath.Join(dir, "Zapuskalka")
	if err := os.MkdirAll(appDir, 0o755); err != nil {
		log.Println(err)
		return
	}

	data, err := json.MarshalIndent(storageList, "", "  ")
	if err != nil {
		log.Println(err)
		return
	}

	configPath := filepath.Join(appDir, "settings.storage.json")
	if err := os.WriteFile(configPath, data, 0o644); err != nil {
		log.Println(err)
		return
	}
}

func (a *App) LoadStorageList() []Storage {
	dir, err := os.UserConfigDir()
	if err != nil {
		log.Println(err)
		return []Storage{}
	}

	configPath := filepath.Join(dir, "Zapuskalka", "settings.storage.json")

	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return []Storage{}
		}
		log.Println(err)
		return []Storage{}
	}

	if len(data) == 0 {
		return []Storage{}
	}

	var storageList []Storage
	if err := json.Unmarshal(data, &storageList); err != nil {
		log.Println(err)
		return []Storage{}
	}

	return storageList
}