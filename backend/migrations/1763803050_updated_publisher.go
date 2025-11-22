package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_4173542366")
		if err != nil {
			return err
		}

		// add field
		if err := collection.Fields.AddMarshaledJSONAt(3, []byte(`{
			"cascadeDelete": false,
			"collectionId": "_pb_users_auth_",
			"hidden": false,
			"id": "relation3479234172",
			"maxSelect": 1,
			"minSelect": 0,
			"name": "owner",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "relation"
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_4173542366")
		if err != nil {
			return err
		}

		// remove field
		collection.Fields.RemoveById("relation3479234172")

		return app.Save(collection)
	})
}
