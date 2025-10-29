class_name LauncherPreferences
extends Resource

const PATH = "user://preferences.tres"

static var instance: LauncherPreferences:
	get:
		if instance:
			return instance

		if ResourceLoader.exists(PATH, "LauncherPreferences"):
			instance = ResourceLoader.load(
				PATH,
				"LauncherPreferences",
				ResourceLoader.CACHE_MODE_REUSE,
			) as LauncherPreferences
		else:
			instance = LauncherPreferences.new()

		return instance

@export_custom(PreferencesSync.PROPERTY_HINT_DONT_RENDER, "")
var installed_app_path: String = ""
@export_custom(PreferencesSync.PROPERTY_HINT_DONT_RENDER, "")
var installed_release_tag: String = ""
@export_custom(PreferencesSync.PROPERTY_HINT_DONT_RENDER, "")
var total_play_time_secs: int = 0
@export_custom(PreferencesSync.PROPERTY_HINT_DONT_RENDER, "")
var last_play_unixtime: int = 0

@export var installation_path: String = "user://releases"
@export var update_automatically: bool = false


func save() -> void:
	print("saving preferences")
	ResourceSaver.save(self, PATH, ResourceSaver.FLAG_NONE)
