extends Control

@onready var play_btn: Button = $PlayBtn
@onready var community_btn: Button = $CommunityBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var actual_version_label: Label = $Header/ActualVersionLabel
@onready var installed_version_label: Label = $Header/InstalledVersionLabel
@onready var http: HTTPRequest = HTTPRequest.new()

const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"
var GITHUB_RELEASE_LATEST_API := "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]

var local_version := ""
var remote_version := ""
var download_url := ""
var is_update_available := false
var _downloading := false
# Флаг для отложенного запуска игры после проверки актуальности
var _pending_play := false
# Путь к папке для игры (будет загружен из настроек)
var game_dir := ""

func _ready() -> void:
	play_btn.disabled = true
	play_btn.text = "Проверка обновления..."
	play_btn.set_meta("action", "checking")
	add_child(http)
	play_btn.pressed.connect(_on_play_btn_pressed)
	settings_btn.pressed.connect(_on_settings_btn_pressed)
	# Загружаем путь к папке игры из настроек
	_load_game_dir_from_settings()
	print("[LOG] Сканирование директории для игры:", game_dir)
	_check_for_updates()

# Загрузка пути к папке игры из user://settings.cfg
func _load_game_dir_from_settings() -> void:
	var config := ConfigFile.new()
	var settings_file := "user://settings.cfg"
	var default_game_dir := ProjectSettings.globalize_path("res://")
	var err = config.load(settings_file)
	if err == OK:
		game_dir = config.get_value("launcher", "game_dir", default_game_dir)
	else:
		game_dir = default_game_dir
func _on_settings_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_play_btn_pressed() -> void:
	if _downloading:
		return
	var action = play_btn.get_meta("action")
	if action == "download" or action == "update":
		_download_game()
	elif action == "play":
		print("[LOG] Повторная проверка версии перед запуском по кнопке 'Играть'")
		# Повторная проверка актуальности версии перед запуском
		_pending_play = true
		_check_for_updates()

func _check_for_updates() -> void:
	play_btn.text = "Проверка обновления..."
	play_btn.set_meta("action", "checking")
	play_btn.disabled = true
	_scan_local_game()
	# Отключаем старый сигнал, чтобы не было дублирующихся вызовов
	if http.request_completed.is_connected(_on_http_request_completed):
		http.request_completed.disconnect(_on_http_request_completed)
	http.request_completed.connect(_on_http_request_completed)
	var err = http.request(GITHUB_RELEASE_LATEST_API, ["User-Agent: GigabahLauncher"])
	if err != OK:
		_set_status("Ошибка подключения к серверу")

func _scan_local_game() -> void:
	var exe_path = _find_local_exe()
	if exe_path != "":
		print("[LOG] Найден файл игры:", exe_path)
		local_version = exe_path.get_file().replace("gigabah_", "").replace(".exe", "")
		installed_version_label.text = "Установленная версия - " + local_version
	else:
		print("[LOG] Файл игры не найден в папке для игры:", game_dir)
		local_version = ""
		installed_version_label.text = "Установленная версия - -"

func _find_local_exe() -> String:
	var dir = DirAccess.open(game_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				return dir.get_current_dir().path_join(f)
	return ""

func _on_http_request_completed(result, code, _headers, body) -> void:
	print("[LOG] Ответ сервера о релизе: result=", result, ", code=", code)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при проверке обновлений")
		_pending_play = false
		return
	# Проверяем, что это действительно JSON, а не бинарный файл
	if body.size() > 1 and body[0] == 77 and body[1] == 90:
		print("[ERROR] Получен бинарный файл вместо JSON, пропускаем парсинг.")
		_pending_play = false
		return
	var body_str = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(body_str) != OK:
		print("[ERROR] Ошибка парсинга JSON: ", json.get_error_line(), json.get_error_message())
		_set_status("Ошибка обработки данных")
		_pending_play = false
		return
	var data = json.data
	var assets = []
	if data.has("assets"):
		assets = data["assets"]
	if data.has("tag_name"):
		remote_version = data["tag_name"].lstrip("v")
	else:
		remote_version = ""
	download_url = ""
	var exe_name = ""
	for asset in assets:
		if asset.has("name") and asset["name"].ends_with(".exe"):
			download_url = asset["browser_download_url"]
			exe_name = asset["name"]
			break
	if download_url == "":
		_set_status("Не найден .exe файл в релизе")
		_pending_play = false
		return
	print("[LOG] Найден .exe файл:", exe_name, "URL:", download_url)
	_compare_versions()
	# Если был запрошен запуск после проверки и версия актуальна, запускаем игру
	if _pending_play:
		_pending_play = false
		if not is_update_available and play_btn.get_meta("action") == "play":
			print("[LOG] Версия актуальна, запускаю игру после повторной проверки.")
			_launch_game()
		else:
			print("[LOG] После повторной проверки обнаружено обновление, запуск отменён.")

func _compare_versions() -> void:
	if local_version == "":
		print("[LOG] Статус: игра не найдена, требуется скачивание.")
		play_btn.text = "Скачать"
		play_btn.set_meta("action", "download")
		play_btn.disabled = false
		is_update_available = true
	elif local_version != remote_version:
		print("[LOG] Статус: доступно обновление, требуется обновить.")
		play_btn.text = "Обновить"
		play_btn.set_meta("action", "update")
		play_btn.disabled = false
		is_update_available = true
	else:
		print("[LOG] Статус: игра актуальна, можно запускать.")
		play_btn.text = "Играть"
		play_btn.set_meta("action", "play")
		play_btn.disabled = false
		is_update_available = false

func _download_game() -> void:
	# Удаляем старые версии gigabah_*.exe перед скачиванием новой
	var dir = DirAccess.open(game_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				var old_path = game_dir.path_join(f)
				if FileAccess.file_exists(old_path):
					print("[LOG] Удаляю старую версию:", old_path)
					dir.remove(f)
	_downloading = true
	play_btn.text = "Скачивание..."
	play_btn.set_meta("action", "downloading")
	play_btn.disabled = true
	_set_status("Загрузка файла игры...")
	var exe_name = "gigabah_%s.exe" % remote_version
	if http.request_completed.is_connected(_on_download_complete):
		http.request_completed.disconnect(_on_download_complete)
	http.request_completed.connect(_on_download_complete.bind(exe_name))
	var err = http.request(download_url)
	if err != OK:
		_set_status("Ошибка при запуске загрузки")


func _on_download_complete(result, code, _headers, body, exe_name) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при загрузке файла")
		play_btn.text = "Повторить"
		play_btn.set_meta("action", "retry")
		play_btn.disabled = false
		_downloading = false
		return
	# Проверяем, что это действительно exe-файл, а не JSON или ошибка
	if body.size() <= 1 or body[0] != 77 or body[1] != 90:
		print("[ERROR] Получен не бинарный файл вместо exe, пропускаем сохранение.")
		_set_status("Ошибка: получен некорректный файл")
		play_btn.text = "Повторить"
		play_btn.set_meta("action", "retry")
		play_btn.disabled = false
		_downloading = false
		return
	var save_path = game_dir.path_join(exe_name)
	print("[LOG] Сохраняю файл игры по пути:", save_path)
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_buffer(body)
		f.close()
		_set_status("Игра успешно установлена")
		# После скачивания перепроверяем наличие файла и обновляем статус кнопки
		_scan_local_game()
		_compare_versions()
	else:
		_set_status("Ошибка: файл не найден после установки")
	play_btn.disabled = false
	_downloading = false

func _launch_game() -> void:
	var exe_path = _find_local_exe()
	if exe_path == "" or not FileAccess.file_exists(exe_path):
		_set_status("Файл игры не найден")
		return
	_set_status("Запуск игры...")
	var pid = OS.create_process(exe_path, [])
	if pid > 0:
		_set_status("Игра запущена (PID: %d)" % pid)
		get_tree().quit()
	else:
		_set_status("Ошибка при запуске игры")

func _set_status(text: String) -> void:
	print("[STATUS] ", text)
