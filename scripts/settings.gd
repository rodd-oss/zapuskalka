extends Control
class_name Settings

@onready var dir_path: LineEdit = $HBoxContainer/DirPath
@onready var select_dir_button: Button = $HBoxContainer/SelectDirButton
@onready var reset_button: Button = $Buttons/ResetButton
@onready var back_button: Button = $Buttons/BackButton


var default_game_dir: String = ProjectSettings.globalize_path("res://")
var settings_file: String = "user://settings.cfg"
var game_dir: String = ""

func _ready() -> void:
	_load_settings()
	select_dir_button.pressed.connect(_on_select_dir_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	dir_path.text = game_dir
	dir_path.placeholder_text = default_game_dir

func _on_select_dir_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = game_dir
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Выберите директорию для игры"
	add_child(dialog)
	dialog.dir_selected.connect(_on_dir_selected)
	dialog.popup_centered()

func _on_dir_selected(dir: String) -> void:
	game_dir = dir
	dir_path.text = game_dir
	_save_settings()

func _on_reset_pressed() -> void:
	game_dir = default_game_dir
	dir_path.text = game_dir
	_save_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LauncherNative.tscn")

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err = config.load(settings_file)
	if err == OK:
		game_dir = config.get_value("launcher", "game_dir", default_game_dir)
	else:
		game_dir = default_game_dir
	dir_path.text = game_dir

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("launcher", "game_dir", game_dir)
	config.save(settings_file)
