extends Control
class_name Settings

@onready var dir_path: LineEdit = $HBoxContainer/DirPath
@onready var select_dir_button: Button = $HBoxContainer/SelectDirButton
@onready var reset_button: Button = $Buttons/ResetButton
@onready var back_button: Button = $Buttons/BackButton

# Используем тот же default путь, что и в лаунчере для консистентности
var default_game_dir: String = OS.get_executable_path().get_base_dir()
var settings_file: String = "user://settings.cfg"
var game_dir: String = ""
var file_dialog: FileDialog = null

func _ready() -> void:
	_load_settings()
	select_dir_button.pressed.connect(_on_select_dir_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	dir_path.text = game_dir
	dir_path.placeholder_text = default_game_dir
	# Делаем поле только для чтения, чтобы избежать ручного ввода некорректных путей
	dir_path.editable = false
	print("[SETTINGS] Загружены настройки. Путь к игре:", game_dir)
	# Создаем FileDialog один раз для повторного использования
	_create_file_dialog()

func _create_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.title = "Выберите директорию для игры"
	file_dialog.dir_selected.connect(_on_dir_selected)
	file_dialog.canceled.connect(_on_dialog_canceled)
	add_child(file_dialog)

func _on_select_dir_pressed() -> void:
	if file_dialog:
		file_dialog.current_dir = game_dir
		file_dialog.popup_centered(Vector2i(800, 600))

func _on_dialog_canceled() -> void:
	print("[SETTINGS] Выбор директории отменён")

func _on_dir_selected(dir: String) -> void:
	# Валидация выбранной директории
	if not DirAccess.dir_exists_absolute(dir):
		_show_error("Выбранная директория не существует!")
		print("[SETTINGS ERROR] Директория не существует:", dir)
		return
	
	# Проверка прав на запись
	var test_file_path = dir.path_join(".launcher_test_write")
	var test_file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if test_file:
		test_file.close()
		DirAccess.remove_absolute(test_file_path)
		print("[SETTINGS] Права на запись проверены для:", dir)
	else:
		_show_error("Нет прав на запись в выбранную директорию!")
		print("[SETTINGS ERROR] Нет прав на запись:", dir)
		return
	
	game_dir = dir
	dir_path.text = game_dir
	_save_settings()
	# Закрываем FileDialog перед показом успеха
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.hide()
	_show_success("Настройки сохранены успешно!")
	print("[SETTINGS] Новый путь сохранён:", game_dir)

func _on_reset_pressed() -> void:
	game_dir = default_game_dir
	dir_path.text = game_dir
	_save_settings()
	_show_success("Настройки сброшены к значениям по умолчанию!")
	print("[SETTINGS] Настройки сброшены к:", default_game_dir)

func _on_back_pressed() -> void:
	print("[SETTINGS] Возврат к лаунчеру")
	get_tree().change_scene_to_file("res://scenes/LauncherNative.tscn")

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err = config.load(settings_file)
	if err == OK:
		game_dir = config.get_value("launcher", "game_dir", default_game_dir)
		print("[SETTINGS] Настройки загружены из файла")
	else:
		game_dir = default_game_dir
		print("[SETTINGS] Файл настроек не найден, используется путь по умолчанию")
	dir_path.text = game_dir

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("launcher", "game_dir", game_dir)
	var err = config.save(settings_file)
	if err == OK:
		print("[SETTINGS] Настройки успешно сохранены в:", settings_file)
	else:
		print("[SETTINGS ERROR] Ошибка сохранения настроек:", err)

func _show_error(message: String) -> void:
	print("[STATUS ERROR] ", message)
	# Закрываем FileDialog перед показом ошибки, чтобы избежать конфликта exclusive child
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.hide()
	
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Ошибка"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): 
		if dialog and is_instance_valid(dialog):
			dialog.queue_free()
	)

func _show_success(message: String) -> void:
	print("[STATUS SUCCESS] ", message)
	# Закрываем FileDialog перед показом успеха, чтобы избежать конфликта exclusive child
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.hide()
	
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Успех"
	add_child(dialog)
	dialog.popup_centered()
	
	# Автоматически закрываем через 2 секунды
	await get_tree().create_timer(2.0).timeout
	if dialog and is_instance_valid(dialog):
		dialog.queue_free()

func _exit_tree() -> void:
	# Очистка при выходе из сцены
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
