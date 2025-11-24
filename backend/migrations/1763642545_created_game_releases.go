package migrations

import (
	"encoding/json"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		jsonData := `{
			"createRule": null,
			"deleteRule": null,
			"fields": [
				{
					"autogeneratePattern": "[a-z0-9]{15}",
					"hidden": false,
					"id": "text3208210256",
					"max": 15,
					"min": 15,
					"name": "id",
					"pattern": "^[a-z0-9]+$",
					"presentable": false,
					"primaryKey": true,
					"required": true,
					"system": true,
					"type": "text"
				},
				{
					"autogeneratePattern": "",
					"hidden": false,
					"id": "text1579384326",
					"max": 100,
					"min": 1,
					"name": "name",
					"pattern": "",
					"presentable": true,
					"primaryKey": false,
					"required": true,
					"system": false,
					"type": "text"
				},
				{
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
				},
				{
					"cascadeDelete": false,
					"collectionId": "pbc_1033968107",
					"hidden": false,
					"id": "relation179463333",
					"maxSelect": 999,
					"minSelect": 0,
					"name": "builds",
					"presentable": false,
					"required": false,
					"system": false,
					"type": "relation"
				},
				{
					"hidden": false,
					"id": "autodate2990389176",
					"name": "created",
					"onCreate": true,
					"onUpdate": false,
					"presentable": false,
					"system": false,
					"type": "autodate"
				},
				{
					"hidden": false,
					"id": "autodate3332085495",
					"name": "updated",
					"onCreate": true,
					"onUpdate": true,
					"presentable": false,
					"system": false,
					"type": "autodate"
				}
			],
			"id": "pbc_988161670",
			"indexes": [
				"CREATE UNIQUE INDEX ` + "`" + `idx_v9UxqwmfzD` + "`" + ` ON ` + "`" + `game_releases` + "`" + ` (\n  ` + "`" + `name` + "`" + `,\n  ` + "`" + `game` + "`" + `\n)",
				"CREATE INDEX ` + "`" + `idx_YF9r1H6jne` + "`" + ` ON ` + "`" + `game_releases` + "`" + ` (` + "`" + `game` + "`" + `)"
			],
			"listRule": null,
			"name": "game_releases",
			"system": false,
			"type": "base",
			"updateRule": null,
			"viewRule": null
		}`

		collection := &core.Collection{}
		if err := json.Unmarshal([]byte(jsonData), &collection); err != nil {
			return err
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("pbc_988161670")
		if err != nil {
			return err
		}

		return app.Delete(collection)
	})
}
