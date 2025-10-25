extends Control

# --[ ENUM ]--
enum LauncherStatus {
	CHECKING,
	DOWNLOAD,
	UPDATE,
	PLAY,
	DOWNLOADING,
	RETRY
}

# --[ NODE REFERENCES ]--
@onready var play_btn: Button = $PlayBtn
@onready var community_btn: Button = $CommunityBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var actual_version_label: Label = $Header/ActualVersionLabel
@onready var installed_version_label: Label = $Header/InstalledVersionLabel
@onready var http: HTTPRequest = HTTPRequest.new()

# --[ CONSTANTS ]--
const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"
const TELEGRAM_CHANNEL := "https://t.me/milanrodd"
var GITHUB_RELEASE_LATEST_API := "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]

# --[ STATE ]--
var local_version := ""
var remote_version := ""
var download_url := ""
var is_update_available := false
var _downloading := false
var _pending_play := false
var game_dir := ""
var status : LauncherStatus = LauncherStatus.CHECKING
var last_exe_name := ""
var last_download_size := 0
var _is_checking_version := false  # Флаг для разделения логики проверки версии и скачивания

func _ready() -> void:
	play_btn.disabled = true
	play_btn.text = "Проверка обновления..."
	status = LauncherStatus.CHECKING
	add_child(http)
	play_btn.pressed.connect(_on_play_btn_pressed)
	settings_btn.pressed.connect(_on_settings_btn_pressed)
	community_btn.pressed.connect(_on_community_btn_pressed)
	# Загружаем путь к папке игры с настройками
	_load_game_dir_from_settings()
	print("[LOG] Сканирование директории для игры:", game_dir)
	_check_for_updates()

# --- Управление статусом кнопки ---
func _set_btn_status(s: LauncherStatus):
	status = s
	match s:
		LauncherStatus.CHECKING:
			play_btn.text = "Проверка обновления..."
			play_btn.disabled = true
		LauncherStatus.DOWNLOAD:
			play_btn.text = "Скачать"
			play_btn.disabled = false
		LauncherStatus.UPDATE:
			play_btn.text = "Обновить"
			play_btn.disabled = false
		LauncherStatus.PLAY:
			play_btn.text = "Играть"
			play_btn.disabled = false
		LauncherStatus.DOWNLOADING:
			play_btn.text = "Скачивание..."
			play_btn.disabled = true
		LauncherStatus.RETRY:
			play_btn.text = "Повторить"
			play_btn.disabled = false

# --- Загрузка пути к папке игры из user://settings.cfg ---
func _load_game_dir_from_settings() -> void:
	var config := ConfigFile.new()
	var settings_file := "user://settings.cfg"
	var default_game_dir := OS.get_executable_path().get_base_dir()
	var err = config.load(settings_file)
	if err == OK:
		game_dir = config.get_value("launcher", "game_dir", default_game_dir)
	else:
		game_dir = default_game_dir
	print("[LOG] Путь к папке игры:", game_dir)

func _on_settings_btn_pressed() -> void:
	if _downloading:
		_set_status("Нельзя переходить в настройки во время скачивания!")
		return
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_community_btn_pressed() -> void:
	OS.shell_open(TELEGRAM_CHANNEL)
	print("[LOG] Открытие Telegram канала:", TELEGRAM_CHANNEL)

func _on_play_btn_pressed() -> void:
	if _downloading:
		return
	match status:
		LauncherStatus.DOWNLOAD, LauncherStatus.UPDATE:
			_download_game()
		LauncherStatus.PLAY:
			_pending_play = true
			_check_for_updates()
		LauncherStatus.RETRY:
			_check_for_updates()
		_:
			pass

func _check_for_updates() -> void:
	_set_btn_status(LauncherStatus.CHECKING)
	_scan_local_game()
	_is_checking_version = true
	if http.request_completed.is_connected(_on_http_request_completed):
		http.request_completed.disconnect(_on_http_request_completed)
		http.cancel_request()
	if http.request_completed.is_connected(_on_download_complete):
		http.request_completed.disconnect(_on_download_complete)
		http.cancel_request()
	http.request_completed.connect(_on_http_request_completed)
	var err = http.request(GITHUB_RELEASE_LATEST_API, ["User-Agent: GigabahLauncher"])
	if err != OK:
		_set_status("Ошибка подключения к серверу")

func _scan_local_game() -> void:
	var exe_path = _find_local_exe()
	if exe_path != "":
		local_version = exe_path.get_file().replace("gigabah_", "").replace(".exe", "")
		installed_version_label.text = "Установленная версия - " + local_version
		print("[LOG] Найден файл игры:", exe_path, "| Версия:", local_version)
	else:
		local_version = ""
		installed_version_label.text = "Установленная версия - -"
		print("[LOG] Файл игры не найден в папке:", game_dir)

func _find_local_exe() -> String:
	var dir = DirAccess.open(game_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				return dir.get_current_dir().path_join(f)
	return ""

func _on_http_request_completed(result, code, headers, body) -> void:
	# Проверяем, что это запрос проверки версии, а не скачивание
	if not _is_checking_version:
		return
	_is_checking_version = false
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при проверке обновлений")
		_pending_play = false
		return
	
	var content_type = ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			content_type = h.split(":")[1].strip_edges().to_lower()
			break
	
	# Проверяем, что это JSON ответ (для API запроса версии)
	if content_type.find("application/json") == -1:
		_set_status("Ошибка: сервер вернул не JSON, возможно, проблема с API!")
		_pending_play = false
		return
	
	if body.size() < 5:
		_set_status("Ошибка обработки данных релиза: слишком мал ответ.")
		_pending_play = false
		return
	
	var body_str = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(body_str) != OK:
		_set_status("Ошибка парсинга JSON: " + str(json.get_error_line()) + " " + json.get_error_message())
		_pending_play = false
		return
	
	var data = json.data
	var assets = []
	if data.has("assets"):
		assets = data["assets"]
	if data.has("tag_name"):
		remote_version = data["tag_name"].lstrip("v")
		actual_version_label.text = "Актуальная версия - " + remote_version
		print("[LOG] Актуальная версия на сервере:", remote_version)
	else:
		remote_version = ""
		actual_version_label.text = "Актуальная версия - -"
	
	download_url = ""
	var exe_name = ""
	for asset in assets:
		if asset.has("name") and asset["name"].ends_with(".exe"):
			download_url = asset["browser_download_url"]
			exe_name = asset["name"]
			break
	
	if not download_url:
		_set_status("Не найден .exe файл в релизе")
		_pending_play = false
		return
	
	last_exe_name = exe_name
	_compare_versions()
	
	if _pending_play:
		_pending_play = false
		if not is_update_available and status == LauncherStatus.PLAY:
			_launch_game()
		else:
			_set_status("После повторной проверки обнаружено обновление, запуск отменён.")

func _compare_versions() -> void:
	if local_version == "":
		_set_btn_status(LauncherStatus.DOWNLOAD)
		is_update_available = true
		print("[LOG] Игра не установлена, требуется скачивание.")
	elif local_version != remote_version:
		_set_btn_status(LauncherStatus.UPDATE)
		is_update_available = true
		print("[LOG] Доступно обновление с версии ", local_version, " до ", remote_version)
	else:
		_set_btn_status(LauncherStatus.PLAY)
		is_update_available = false
		print("[LOG] Игра актуальна, версия:", local_version)

func _download_game() -> void:
	if _downloading:
		return
	# Удаляем старые gigabah_*.exe
	var dir = DirAccess.open(game_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				var old_path = game_dir.path_join(f)
				if FileAccess.file_exists(old_path):
					print("[LOG] Удаление старой версии:", old_path)
					dir.remove(f)
	
	_downloading = true
	_is_checking_version = false  # Отключаем флаг проверки версии для скачивания
	_set_btn_status(LauncherStatus.DOWNLOADING)
	_set_status("Загрузка файла игры...")
	
	var exe_name = "gigabah_%s.exe" % remote_version
	last_exe_name = exe_name
	
	if http.request_completed.is_connected(_on_http_request_completed):
		http.request_completed.disconnect(_on_http_request_completed)
	if http.request_completed.is_connected(_on_download_complete):
		http.request_completed.disconnect(_on_download_complete)
		http.cancel_request()
	
	http.request_completed.connect(_on_download_complete.bind(exe_name))
	var err = http.request(download_url, ["User-Agent: GigabahLauncher"])
	if err != OK:
		_set_status("Ошибка при запуске загрузки")
		_downloading = false

func _on_download_complete(result, code, headers, body, exe_name) -> void:
	_downloading = false
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при загрузке файла")
		_set_btn_status(LauncherStatus.RETRY)
		return
	
	var content_type = ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			content_type = h.split(":")[1].strip_edges().to_lower()
			break
	
	# Для скачивания бинарного файла ожидаем octet-stream или application/x-msdownload
	if content_type.find("application/octet-stream") == -1 and content_type.find("application/x-msdownload") == -1 and content_type.find("application/x-msdos-program") == -1:
		print("[WARNING] Content-Type:", content_type, "- может быть не бинарным файлом")
	
	if body.size() <= 1024 * 1024:
		_set_status("Ошибка: файл слишком мал для exe, возможна ошибка загрузки!")
		_set_btn_status(LauncherStatus.RETRY)
		return
	
	# Проверка сигнатуры MZ
	if body.size() > 1 and body[0] == 77 and body[1] == 90:
		var save_path = game_dir.path_join(exe_name)
		print("[LOG] Сохранение игры по пути:", save_path)
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_buffer(body)
			f.close()
			_set_status("Игра успешно установлена!")
			print("[LOG] Игра успешно сохранена, размер:", body.size(), "байт")
			# Автоматическая перепроверка после скачивания
			_scan_local_game()
			_compare_versions()
		else:
			_set_status("Ошибка: не удалось сохранить файл")
			_set_btn_status(LauncherStatus.RETRY)
	else:
		_set_status("Ошибка: получен некорректный файл")
		_set_btn_status(LauncherStatus.RETRY)

func _launch_game() -> void:
	var exe_path = _find_local_exe()
	if exe_path == "" or not FileAccess.file_exists(exe_path):
		_set_status("Файл игры не найден")
		return
	_set_status("Запуск игры...")
	print("[LOG] Запуск игры:", exe_path)
	var pid = OS.create_process(exe_path, [])
	if pid > 0:
		_set_status("Игра запущена (PID: %d)" % pid)
		print("[LOG] Игра запущена с PID:", pid)
		get_tree().quit()
	else:
		_set_status("Ошибка при запуске игры")

func _set_status(text: String) -> void:
	print("[STATUS] ", text)
