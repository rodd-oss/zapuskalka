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
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `app` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (` + "`" + `app` + "`" + `)"
			]
		}`), &collection); err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(2, []byte(`{
			"cascadeDelete": false,
			"collectionId": "pbc_879072730",
			"hidden": false,
			"id": "relation590033292",
			"maxSelect": 1,
			"minSelect": 0,
			"name": "app",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "relation"
		}`)); err != nil {
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
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `game` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `app_releases` + "`" + ` (` + "`" + `game` + "`" + `)"
			]
		}`), &collection); err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(2, []byte(`{
			"cascadeDelete": false,
			"collectionId": "pbc_879072730",
			"hidden": false,
			"id": "relation590033292",
			"maxSelect": 1,
			"minSelect": 0,
			"name": "game",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "relation"
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
