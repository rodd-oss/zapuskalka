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
			"cascadeDelete": true,
			"collectionId": "pbc_879072730",
			"hidden": false,
			"id": "relation590033292",
			"maxSelect": 1,
			"minSelect": 0,
			"name": "app",
			"presentable": true,
			"required": true,
			"system": false,
			"type": "relation"
		}`)); err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(3, []byte(`{
			"hidden": false,
			"id": "select1789936913",
			"maxSelect": 1,
			"name": "os",
			"presentable": true,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"windows",
				"linux",
				"macos"
			]
		}`)); err != nil {
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

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(5, []byte(`{
			"hidden": false,
			"id": "autodate2990389176",
			"name": "created",
			"onCreate": true,
			"onUpdate": false,
			"presentable": true,
			"system": false,
			"type": "autodate"
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
			"cascadeDelete": true,
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

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(3, []byte(`{
			"hidden": false,
			"id": "select1789936913",
			"maxSelect": 1,
			"name": "os",
			"presentable": false,
			"required": true,
			"system": false,
			"type": "select",
			"values": [
				"windows",
				"linux",
				"macos"
			]
		}`)); err != nil {
			return err
		}

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(4, []byte(`{
			"hidden": false,
			"id": "select4161937994",
			"maxSelect": 1,
			"name": "arch",
			"presentable": false,
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

		// update field
		if err := collection.Fields.AddMarshaledJSONAt(5, []byte(`{
			"hidden": false,
			"id": "autodate2990389176",
			"name": "created",
			"onCreate": true,
			"onUpdate": false,
			"presentable": false,
			"system": false,
			"type": "autodate"
		}`)); err != nil {
			return err
		}

		return app.Save(collection)
	})
}
