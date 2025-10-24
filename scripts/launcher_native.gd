extends Control

@onready var play_btn: Button = $PlayBtn
@onready var community_btn: Button = $CommunityBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var status_indicators: HBoxContainer = $Header/StatusIndicators
@onready var version_label: Label = $Header/Logo/Version

# Прогресс-бар для скачивания
@onready var download_progress: ProgressBar = $DownloadProgress

const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"
var GITHUB_RELEASE_LATEST_API := "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]

var local_version := ""
var remote_version := ""
var download_url := ""
var is_update_available := false
var _downloading := false

# Для отслеживания прогресса скачивания
var _download_total: int = 0
var _downloaded: int = 0

@onready var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	play_btn.disabled = true
	play_btn.text = "Проверка обновления..."
	add_child(http)
	play_btn.pressed.connect(_on_play_btn_pressed)
	print("[LOG] Сканирование директории лаунчера на наличие файла игры...")
	_check_for_updates()

	# Скрываем прогресс-бар по умолчанию
	download_progress.visible = false
	download_progress.value = 0

func _on_play_btn_pressed() -> void:
	if _downloading:
		return
	if play_btn.text == "Скачать" or play_btn.text == "Обновить":
		_download_game()
	elif play_btn.text == "Играть":
		_launch_game()

func _check_for_updates() -> void:
	play_btn.text = "Проверка обновления..."
	play_btn.disabled = true
	_scan_local_game()
	var err = http.request(GITHUB_RELEASE_LATEST_API, ["User-Agent: GigabahLauncher"])
	if err != OK:
		_set_status("Ошибка подключения к серверу")
	http.request_completed.connect(_on_http_request_completed)

func _scan_local_game() -> void:
	var exe_path = _find_local_exe()
	if exe_path != "":
		print("[LOG] Найден файл игры:", exe_path)
		local_version = exe_path.get_file().replace("gigabah_", "").replace(".exe", "")
		version_label.text = "v" + local_version
	else:
		print("[LOG] Файл игры не найден в директории лаунчера.")
		local_version = ""
		version_label.text = "v-"

func _find_local_exe() -> String:
	var dir = DirAccess.open(OS.get_executable_path().get_base_dir())
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				return dir.get_current_dir().path_join(f)
	return ""

func _on_http_request_completed(result, code, _headers, body) -> void:
	print("[LOG] Ответ сервера о релизе: result=", result, ", code=", code)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при проверке обновлений")
		return
	var body_str = body.get_string_from_utf8()
	# Проверяем, что это действительно JSON, а не бинарный файл
	if body_str.length() > 1 and body_str[0] == 'M' and body_str[1] == 'Z':
		print("[ERROR] Получен бинарный файл вместо JSON, пропускаем парсинг.")
		return
	var json = JSON.new()
	if json.parse(body_str) != OK:
		print("[ERROR] Ошибка парсинга JSON: ", json.get_error_line(), json.get_error_message())
		_set_status("Ошибка обработки данных")
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
		return
	print("[LOG] Найден .exe файл:", exe_name, "URL:", download_url)
	_compare_versions()

func _compare_versions() -> void:
	if local_version == "":
		print("[LOG] Статус: игра не найдена, требуется скачивание.")
		play_btn.text = "Скачать"
		play_btn.disabled = false
		is_update_available = true
	elif local_version != remote_version:
		print("[LOG] Статус: доступно обновление, требуется обновить.")
		play_btn.text = "Обновить"
		play_btn.disabled = false
		is_update_available = true
	else:
		print("[LOG] Статус: игра актуальна, можно запускать.")
		play_btn.text = "Играть"
		play_btn.disabled = false
		is_update_available = false

func _download_game() -> void:
	# Удаляем старые версии gigabah_*.exe перед скачиванием новой
	var exe_dir = OS.get_executable_path().get_base_dir()
	var dir = DirAccess.open(exe_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				var old_path = exe_dir.path_join(f)
				if FileAccess.file_exists(old_path):
					print("[LOG] Удаляю старую версию:", old_path)
					dir.remove(f)
	_downloading = true
	play_btn.text = "Скачивание..."
	play_btn.disabled = true
	_set_status("Загрузка файла игры...")
	var exe_name = "gigabah_%s.exe" % remote_version
	if http.request_completed.is_connected(_on_download_complete):
		http.request_completed.disconnect(_on_download_complete)
	http.request_completed.connect(_on_download_complete.bind(exe_name))
	var err = http.request(download_url)
	if err != OK:
		_set_status("Ошибка при запуске загрузки")

	# Показываем прогресс-бар и сбрасываем значение
	download_progress.visible = true
	download_progress.value = 0
	_download_total = 0
	_downloaded = 0

func _on_download_complete(result, code, _headers, body, exe_name) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при загрузке файла")
		play_btn.text = "Повторить"
		play_btn.disabled = false
		_downloading = false
		download_progress.visible = false
		return
	var save_path = ProjectSettings.globalize_path("res://" + exe_name)
	print("[LOG] Сохраняю файл игры по пути:", save_path)
	var f = FileAccess.open(exe_name, FileAccess.WRITE)
	if f:
		f.store_buffer(body)
		f.close()
		_set_status("Игра успешно установлена")
		# После скачивания перепроверяем наличие файла и обновляем статус кнопки
		_scan_local_game()
		_compare_versions()
		download_progress.visible = false
	else:
		_set_status("Ошибка: файл не найден после установки")
	play_btn.disabled = false
	_downloading = false
	download_progress.visible = false
	download_progress.value = 0

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
	for child in status_indicators.get_children():
		status_indicators.remove_child(child)
		child.queue_free()
	var label = Label.new()
	label.text = text
	status_indicators.add_child(label)
