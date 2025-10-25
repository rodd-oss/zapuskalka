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
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var progress_label: Label = $ProgressLabel
@onready var speed_label: Label = $SpeedLabel
@onready var news_container: VBoxContainer = $NewsPanel/LastNewsPanel/ScrollContainer/VBoxContainer
@onready var server_indicator: ColorRect = $ServerStatusIndicator
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
var launcher_status : LauncherStatus = LauncherStatus.CHECKING
var last_exe_name := ""
var _is_checking_version := false
var _download_start_time := 0.0

# --[ MODULES ]--
var news_parser: NewsParser = null
var server_monitor: ServerMonitor = null


func _ready() -> void:
	play_btn.disabled = true
	play_btn.text = "Проверка обновления..."
	launcher_status = LauncherStatus.CHECKING
	add_child(http)
	
	# Инициализация прогресс-бара
	_init_progress_bar()
	
	# Инициализация парсера новостей
	_init_news_parser()
	
	# Инициализация монитора сервера
	_init_server_monitor()
	
	play_btn.pressed.connect(_on_play_btn_pressed)
	settings_btn.pressed.connect(_on_settings_btn_pressed)
	community_btn.pressed.connect(_on_community_btn_pressed)
	
	# Загружаем путь к папке игры с настройками
	_load_game_dir_from_settings()
	print("[LOG] Сканирование директории для игры:", game_dir)
	
	# Загружаем обновления и новости
	_check_for_updates()
	_load_news()


# --- Инициализация монитора сервера ---
func _init_server_monitor() -> void:
	server_monitor = ServerMonitor.new()
	add_child(server_monitor)
	server_monitor.status_changed.connect(_on_server_status_changed)
	
	# Проверяем статус каждые 30 секунд
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(func(): _check_server_sync())
	add_child(timer)
	timer.start()
	
	# Первая проверка сразу (синхронно)
	_check_server_sync()
	print("[LOG] ServerMonitor инициализирован")


# --- Синхронная проверка сервера ---
func _check_server_sync() -> void:
	server_monitor.check_server_status()


func _on_server_status_changed(new_status: String) -> void:
	print("[LOG] Статус сервера изменился: %s" % new_status)
	_update_server_indicator_visual(new_status)


func _update_server_indicator_visual(server_state: String) -> void:
	if not is_instance_valid(server_indicator):
		return
	
	server_indicator.set_status(server_state)
	
	match server_state:
		"online":
			print("[ServerIndicator] Сервер онлайн - зелёный индикатор")
		"offline":
			print("[ServerIndicator] Сервер офлайн - красный индикатор")
		"error":
			print("[ServerIndicator] Ошибка проверки - жёлтый индикатор")
		_:
			print("[ServerIndicator] Проверка статуса - серый индикатор (пульсирует)")



# Обновление UI прогресса в _process 
func _process(_delta: float) -> void:
	if _downloading and http:
		var total_bytes = http.get_body_size()
		var downloaded_bytes = http.get_downloaded_bytes()
		
		# Обновляем UI только если известен размер файла
		if total_bytes > 0:
			var percent = float(downloaded_bytes) / total_bytes
			progress_bar.value = percent * 100
			
			# Рассчитываем скорость загрузки
			var elapsed_time = Time.get_unix_time_from_system() - _download_start_time
			var speed_kbps = 0.0
			var speed_mbps = 0.0
			
			if elapsed_time > 0:
				speed_kbps = (float(downloaded_bytes) / elapsed_time) / 1024.0  # KB/s
				speed_mbps = speed_kbps / 1024.0  # MB/s
			
			# Форматируем размеры в MB
			var downloaded_mb = float(downloaded_bytes) / (1024.0 * 1024.0)
			var total_mb = float(total_bytes) / (1024.0 * 1024.0)
			
			# Форматируем скорость (выбираем единицу автоматически)
			var speed_str = ""
			if speed_mbps > 0.1:
				speed_str = "%.2f MB/s" % speed_mbps
			else:
				speed_str = "%.2f KB/s" % speed_kbps
			
			progress_label.text = "Загрузка: %d%%\n%.2f MB / %.2f MB" % [int(percent * 100), downloaded_mb, total_mb]
			speed_label.text = "Скорость: %s" % speed_str
		else:
			# Если сервер не предоставил размер файла
			progress_label.text = "Загрузка..."
			speed_label.text = "Скорость: определяется..."


# --- Инициализация парсера новостей ---
func _init_news_parser() -> void:
	news_parser = NewsParser.new()
	add_child(news_parser)
	
	news_parser.releases_loaded.connect(_on_releases_loaded)
	news_parser.news_item_added.connect(_on_news_item_added)
	news_parser.loading_error.connect(_on_news_loading_error)
	
	print("[LOG] NewsParser инициализирован")


# --- Загрузка новостей ---
func _load_news() -> void:
	if news_parser:
		print("[LOG] Загрузка новостей с GitHub...")
		news_parser.load_releases(5)


# --- Обработчик загрузки релизов ---
func _on_releases_loaded(releases: Array) -> void:
	print("[LOG] Обработано %d релизов" % releases.size())


# --- Обработчик добавления новости ---
func _on_news_item_added(version: String, changes: String, published: String) -> void:
	var release_info = news_parser.format_release_for_display(version, changes, published)
	_display_news_item(release_info)


# --- Обработчик ошибки загрузки новостей ---
func _on_news_loading_error(error_message: String) -> void:
	print("[NEWS ERROR] %s" % error_message)


# --- Отображение блока новости в UI ---
func _display_news_item(release_info: Dictionary) -> void:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	var title = Label.new()
	title.text = release_info.get("title", "Unknown")
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var changes_label = RichTextLabel.new()
	changes_label.bbcode_enabled = true
	changes_label.fit_content = true
	changes_label.scroll_active = false
	changes_label.mouse_filter = Control.MOUSE_FILTER_STOP
	changes_label.add_theme_color_override("font_color", Color.WHITE)
	changes_label.add_theme_color_override("font_focus_color", Color.YELLOW)
	changes_label.meta_clicked.connect(_on_meta_clicked)
	
	var formatted_changes = _convert_markdown_to_bbcode(release_info.get("changes", ""))
	changes_label.text = formatted_changes
	
	vbox.add_child(changes_label)
	panel.add_child(vbox)
	news_container.add_child(panel)
	
	print("[LOG] Добавлена новость: %s" % release_info.get("title", "Unknown"))


# --- Обработчик клика на ссылку ---
func _on_meta_clicked(meta: Variant) -> void:
	var url = str(meta)
	print("[LOG] Клик на ссылку: %s" % url)
	OS.shell_open(url)


# --- Преобразование Markdown ссылок в BBCode для RichTextLabel ---
func _convert_markdown_to_bbcode(text: String) -> String:
	var result = text
	var regex = RegEx.new()
	regex.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	
	var matches = regex.search_all(result)
	for i in range(matches.size() - 1, -1, -1):
		var match = matches[i]
		var link_text = match.get_string(1)
		var link_url = match.get_string(2)
		var full_match = match.get_string(0)
		
		var bbcode_link = "[meta=%s]%s[/meta]" % [link_url, link_text]
		result = result.replace(full_match, bbcode_link)
	
	return result


# --- Инициализация прогресс-бара ---
func _init_progress_bar() -> void:
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.visible = false
	progress_label.visible = false
	speed_label.visible = false
	print("[LOG] Прогресс-бар инициализирован")


# --- Управление статусом кнопки ---
func _set_btn_status(s: LauncherStatus):
	launcher_status = s
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
	match launcher_status:
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
		if not is_update_available and launcher_status == LauncherStatus.PLAY:
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
		print("[LOG] Доступно обновление с версии", local_version, "до", remote_version)
	else:
		_set_btn_status(LauncherStatus.PLAY)
		is_update_available = false
		print("[LOG] Игра актуальна, версия:", local_version)


func _download_game() -> void:
	if _downloading:
		return
	var dir = DirAccess.open(game_dir)
	if dir:
		for f in dir.get_files():
			if f.begins_with("gigabah_") and f.ends_with(".exe"):
				var old_path = game_dir.path_join(f)
				if FileAccess.file_exists(old_path):
					print("[LOG] Удаление старой версии:", old_path)
					dir.remove(f)
	
	_downloading = true
	_is_checking_version = false
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
	
	progress_bar.visible = true
	progress_label.visible = true
	speed_label.visible = true
	progress_bar.value = 0
	progress_label.text = "Начало загрузки..."
	speed_label.text = "Скорость: определяется..."
	
	# Сохраняем время начала в unix timestamp для точного расчета
	_download_start_time = Time.get_unix_time_from_system()
	
	var err = http.request(download_url, ["User-Agent: GigabahLauncher"])
	if err != OK:
		_set_status("Ошибка при запуске загрузки")
		_downloading = false
		progress_bar.visible = false
		progress_label.visible = false
		speed_label.visible = false


func _format_bytes(bytes: int) -> String:
	var file_size = float(bytes)
	var units = ["B", "KB", "MB", "GB"]
	var unit_index = 0
	while file_size >= 1024 and unit_index < units.size() - 1:
		file_size /= 1024
		unit_index += 1
	return "%.2f %s" % [file_size, units[unit_index]]


func _on_download_complete(result, code, headers, body, exe_name) -> void:
	_downloading = false
	
	progress_bar.value = 100
	var downloaded_mb = float(body.size()) / (1024.0 * 1024.0)
	progress_label.text = "Загрузка: 100%%\n%.2f MB" % downloaded_mb
	speed_label.text = "Загрузка завершена!"
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("Ошибка при загрузке файла")
		_set_btn_status(LauncherStatus.RETRY)
		progress_bar.visible = false
		progress_label.visible = false
		speed_label.visible = false
		return
	
	var content_type = ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			content_type = h.split(":")[1].strip_edges().to_lower()
			break
	
	if content_type.find("application/octet-stream") == -1 and content_type.find("application/x-msdownload") == -1 and content_type.find("application/x-msdos-program") == -1:
		print("[WARNING] Content-Type:", content_type, "- может быть не бинарным файлом")
	
	if body.size() <= 1024 * 1024:
		_set_status("Ошибка: файл слишком мал для exe, возможна ошибка загрузки!")
		_set_btn_status(LauncherStatus.RETRY)
		progress_bar.visible = false
		progress_label.visible = false
		speed_label.visible = false
		return
	
	if body.size() > 1 and body[0] == 77 and body[1] == 90:
		var save_path = game_dir.path_join(exe_name)
		print("[LOG] Сохранение игры по пути:", save_path)
		var f = FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_buffer(body)
			f.close()
			_set_status("Игра успешно установлена!")
			print("[LOG] Игра успешно сохранена, размер:", _format_bytes(body.size()))
			progress_bar.visible = false
			progress_label.visible = false
			speed_label.visible = false
			_scan_local_game()
			_compare_versions()
		else:
			_set_status("Ошибка: не удалось сохранить файл")
			_set_btn_status(LauncherStatus.RETRY)
			progress_bar.visible = false
			progress_label.visible = false
			speed_label.visible = false
	else:
		_set_status("Ошибка: получен некорректный файл")
		_set_btn_status(LauncherStatus.RETRY)
		progress_bar.visible = false
		progress_label.visible = false
		speed_label.visible = false


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
