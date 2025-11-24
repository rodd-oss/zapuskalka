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
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `app_branches` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `app` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `app_branches` + "`" + ` (` + "`" + `app` + "`" + `)"
			],
			"name": "app_branches"
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
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `app` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (` + "`" + `app` + "`" + `)"
			],
			"name": "app_releases"
		}`), &collection); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
