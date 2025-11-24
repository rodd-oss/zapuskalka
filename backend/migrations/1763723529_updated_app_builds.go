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
		if err := collection.Fields.AddMarshaledJSONAt(4, []byte(`{
			"hidden": false,
			"id": "select4161937994",
			"maxSelect": 1,
			"name": "arch",
			"presentable": true,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"x86_64",
				"arm",
				"aarch64",
				"universal",
				"x86"
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
		if err := collection.Fields.AddMarshaledJSONAt(4, []byte(`{
			"hidden": false,
			"id": "select4161937994",
			"maxSelect": 1,
			"name": "arch",
			"presentable": true,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"x86_64",
				"arm",
				"aarch64",
				"universal"
			]
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
