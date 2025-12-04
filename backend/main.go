package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	// enable once you have at least one migration
	_ "zapuskalka-backend/migrations"
)

func main() {
	app := pocketbase.New()

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		// serves static files from the provided public dir (if exists)
		se.Router.GET("/{path...}", apis.Static(os.DirFS("./web/dist"), true))
		se.Router.POST("/api/get-app-token", func(e *core.RequestEvent) error {
			data := struct {
				Token string `json:"token" form:"token"`
			}{}

			if err := e.BindBody(&data); err != nil {
				return e.BadRequestError("Failed to read request data", err)
			}

			record, err := e.App.FindFirstRecordByData("_authCode", "token", data.Token)
			if err != nil {
				return e.BadRequestError("Token not found", err)
			}

			user, err := e.App.FindRecordById("users", record.GetString("user"))
			if err != nil {
				return e.BadRequestError("Failed to get current user", err)
			}

			e.App.Delete(record)

			return apis.RecordAuthResponse(e, user, "app", nil)

		})

		return se.Next()
	})

	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Dashboard
		Dir:         "./migrations",
		Automigrate: AutoMigrate,
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
