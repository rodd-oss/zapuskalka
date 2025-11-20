package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_1033968107")
		if err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(2, []byte(`{
			"hidden": false,
			"id": "select1542800728",
			"maxSelect": 1,
			"name": "target",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"windows-x86_64",
				"windows-arm64",
				"linux-x86_64",
				"linux-arm64",
				"macos-universal"
			]
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_1033968107")
		if err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(2, []byte(`{
			"hidden": false,
			"id": "select1542800728",
			"maxSelect": 1,
			"name": "field",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"windows-x86_64",
				"windows-arm64",
				"linux-x86_64",
				"linux-arm64",
				"macos-universal"
			]
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
