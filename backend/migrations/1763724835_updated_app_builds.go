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

		// add field
		if err := collection.Fields.AddMarshaledJSONAt(5, []byte(`{
			"hidden": false,
			"id": "select3979995827",
			"maxSelect": 1,
			"name": "install_rules",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"direct_copy"
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

		// remove field
		collection.Fields.RemoveById("select3979995827")

		return app.Save(collection)
	})
}
