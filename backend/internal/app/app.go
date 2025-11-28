package app

import (
	"log/slog"
	"os"

	"zapuskalka-backend/internal/config"
	"zapuskalka-backend/internal/handlers"

	"github.com/olivere/vite"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/romsar/gonertia"
)

type App struct {
	app    *pocketbase.PocketBase
	cfg    *config.Config
	logger *slog.Logger

	isDev bool
}

func New(cfg *config.Config) *App {
	app := pocketbase.New()

	return &App{
		app:    app,
		logger: app.Logger(),
		cfg:    cfg,
		isDev:  app.IsDev(),
	}
}

func (a *App) Start() error {
	migratecmd.MustRegister(a.app, a.app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Dashboard
		Dir:         "./migrations",
		Automigrate: AutoMigrate,
	})

	inertia, err := gonertia.NewFromFile("index.html")
	if err != nil {
		return err
	}

	vf, err := vite.HTMLFragment(vite.Config{
		FS:           os.DirFS(a.cfg.DistDir),
		IsDev:        a.isDev,
		ViteURL:      a.cfg.ViteURL,
		ViteEntry:    a.cfg.ViteEntry,
		ViteTemplate: vite.VueTs,
	})
	if err != nil {
		return err
	}

	inertia.ShareTemplateData("Vite", vf)

	h := handlers.New(inertia, a.logger)

	a.app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		a.registerRoutes(se, h, a.cfg)
		return se.Next()
	})

	return a.app.Start()
}

func (a *App) registerRoutes(se *core.ServeEvent, h *handlers.Handler, cfg *config.Config) {
	if a.isDev {
		se.Router.GET("/src/assets/{path...}", apis.Static(os.DirFS(cfg.AssetsDir), false))
	} else {
		se.Router.GET("/assets/{path...}", apis.Static(os.DirFS(cfg.DistDir+"/assets"), false))
	}

	se.Router.GET("/", apis.WrapStdHandler(h.Home()))
	se.Router.GET("/login", apis.WrapStdHandler(h.Login()))
	se.Router.GET("/oauth/{provider}/callback", apis.WrapStdHandler(h.OAuthCallback()))
}
