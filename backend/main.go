package main

import (
	"log"
	"log/slog"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	// enable once you have at least one migration
	_ "zapuskalka-backend/migrations"
	"zapuskalka-backend/typegen"
)

func main() {
	app := pocketbase.New()

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		// serves static files from the provided public dir (if exists)
		se.Router.GET("/{path...}", apis.Static(os.DirFS("./dist"), true))
		se.Router.POST("/api/get-app-token", func(e *core.RequestEvent) error {
			data := struct {
				AuthCode string `json:"authCode" form:"authCode"`
			}{}

			if err := e.BindBody(&data); err != nil {
				return e.BadRequestError("Failed to read request data", err)
			}

			authCode, err := e.App.FindRecordById("_authCode", data.AuthCode)
			if err != nil {
				return e.BadRequestError("Auth code not found", err)
			}

			user, err := e.App.FindRecordById("users", authCode.GetString("user"))
			if err != nil {
				return e.BadRequestError("Failed to get current user", err)
			}

			err = e.App.Delete(authCode)
			if err != nil {
				app.Logger().Log(e.Request.Context(), slog.LevelError, "Failed to delete _authCode"+err.Error())
				return e.InternalServerError("Failed to delete _authCode", nil)
			}

			return apis.RecordAuthResponse(e, user, "app", nil)

		})

		return se.Next()
	})

	if app.IsDev() {
		typegen.MustRegister(app, typegen.Config{
			OutputDir:         "../packages/backend-api",
			GenerateOnStartup: true,
		})
	}

	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Dashboard
		Dir:         "./migrations",
		Automigrate: AutoMigrate,
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
