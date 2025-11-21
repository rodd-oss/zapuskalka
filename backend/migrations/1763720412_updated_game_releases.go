package migrations

import (
	"encoding/json"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_988161670")
		if err != nil {
			return err
		}

		// update collection data
		if err := json.Unmarshal([]byte(`{
			"indexes": [
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `game` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (` + "`" + `game` + "`" + `)"
			],
			"name": "app_releases"
		}`), &collection); err != nil {
			return err
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_988161670")
		if err != nil {
			return err
		}

		// update collection data
		if err := json.Unmarshal([]byte(`{
			"indexes": [
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `game_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `game` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `game_releases` + "`" + ` (` + "`" + `game` + "`" + `)"
			],
			"name": "game_releases"
		}`), &collection); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
