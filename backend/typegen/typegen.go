package typegen

import (
	"log/slog"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

type plugin struct {
	app       core.App
	config    Config
	generator *TypeGenerator
}

func MustRegister(app core.App, config Config) {
	if err := Register(app, config); err != nil {
		panic(err)
	}
}

func Register(app core.App, config Config) error {
	p := &plugin{
		app:       app,
		config:    config,
		generator: NewTypeGenerator(),
	}

	if p.config.OutputDir == "" {
		p.config.OutputDir = app.DataDir()
	}

	p.app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if p.config.GenerateOnStartup {
			if err := p.generator.Generate(p.app, p.config); err != nil {
				p.app.Logger().Warn(
					"Failed to generate custom types on startup",
					slog.String("error", err.Error()),
				)
			} else {
				p.app.Logger().Info("Generated TypeScript types successfully")
			}
		}
		return e.Next()
	})

	p.bindCollectionChangeHandler(p.app.OnCollectionAfterCreateSuccess(), "create")
	p.bindCollectionChangeHandler(p.app.OnCollectionAfterUpdateSuccess(), "update")
	p.bindCollectionChangeHandler(p.app.OnCollectionAfterDeleteSuccess(), "delete")

	return nil
}

func (p *plugin) bindCollectionChangeHandler(h *hook.TaggedHook[*core.CollectionEvent], action string) {
	h.BindFunc(func(e *core.CollectionEvent) error {
		if err := p.generator.Generate(p.app, p.config); err != nil {
			p.app.Logger().Warn(
				"Failed to regenerate types after collection "+action,
				slog.String("collection", e.Collection.Name),
				slog.String("error", err.Error()),
			)
		} else {
			p.app.Logger().Debug(
				"Regenerated TypeScript types after collection "+action,
				slog.String("collection", e.Collection.Name),
			)
		}
		return e.Next()
	})
}
