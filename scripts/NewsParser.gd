extends Control
class_name NewsParser

# --[ CONSTANTS ]--
const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"

# --[ STATE ]--
var _http: HTTPRequest = null
var _regex_li: RegEx = RegEx.new()
var _regex_tags: RegEx = RegEx.new()
var _regex_spaces: RegEx = RegEx.new()
var _regex_links: RegEx = RegEx.new()

# --[ SIGNALS ]--
signal releases_loaded(releases: Array)
signal news_item_added(version: String, changes: String, published: String)
signal loading_error(error_message: String)

func _init() -> void:
	# Инициализируем regex паттерны
	_regex_li.compile("<li>(.*?)</li>")
	_regex_tags.compile("<[^>]*>")
	_regex_spaces.compile("\\s+")
	_regex_links.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	print("[NewsParser] Инициализирован")

# --- Загрузка последних релизов с GitHub ---
func load_releases(count: int = 5) -> void:
	# Создаем HTTPRequest если еще не создан
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
		_http.request_completed.connect(_on_releases_loaded)
		print("[NewsParser] HTTPRequest добавлен в дерево и обработчик подключен")
	
	var releases_api = "https://api.github.com/repos/%s/%s/releases?per_page=%d" % [GITHUB_OWNER, GITHUB_REPO, count]
	
	print("[NewsParser] Запрос релизов: %s" % releases_api)
	var err = _http.request(releases_api, ["User-Agent: GigabahLauncher"])
	if err != OK:
		print("[NewsParser ERROR] Ошибка при запросе релизов: %d" % err)
		loading_error.emit("Ошибка подключения к GitHub API")

# --- Обработчик загрузки релизов ---
func _on_releases_loaded(result, code, _headers, body) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("[NewsParser ERROR] Ошибка загрузки: result=%d, code=%d" % [result, code])
		loading_error.emit("Не удалось загрузить список релизов")
		return
	
	var body_str = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(body_str) != OK:
		print("[NewsParser ERROR] Ошибка парсинга JSON")
		loading_error.emit("Ошибка парсинга данных релизов")
		return
	
	var releases = json.data
	print("[NewsParser] Загружено %d релизов" % releases.size())
	
	# Отправляем сигнал с загруженными релизами
	releases_loaded.emit(releases)
	
	# Обрабатываем каждый релиз
	for release in releases:
		_process_release(release)

# --- Обработка одного релиза ---
func _process_release(release: Dictionary) -> void:
	var version = release.get("tag_name", "Unknown")
	var body = release.get("body", "")
	var published = release.get("published_at", "").substr(0, 10)
	
	# Извлекаем "What's Changed" из Markdown
	var changes = extract_whats_changed_markdown(body)
	
	if changes != "":
		print("[NewsParser] Версия %s: %d строк изменений" % [version, changes.split("\n").size()])
		news_item_added.emit(version, changes, published)
	else:
		print("[NewsParser] Версия %s: нет изменений или пустой body" % version)

# --- Извлечение "What's Changed" из Markdown ---
func extract_whats_changed_markdown(body: String) -> String:
	if body == "":
		return ""
	
	# Ищем начало секции "What's Changed"
	var start_marker = "## What's Changed"
	var start = body.find(start_marker)
	
	if start == -1:
		print("[NewsParser WARNING] 'What's Changed' секция не найдена")
		return ""
	
	start += start_marker.length()
	
	# Ищем конец (начало Full Changelog)
	var end_marker = "**Full Changelog**"
	var end = body.find(end_marker, start)
	
	if end == -1:
		end = body.length()
	
	# Извлекаем содержимое между маркерами
	var changes_text = body.substr(start, end - start)
	
	# Парсим все пункты списка (ищем "* " в markdown)
	var result = ""
	var lines = changes_text.split("\n")
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.begins_with("* "):
			var clean_line = trimmed.substr(2)  # Убираем "* "
			result += "• " + clean_line + "\n"
	
	return result

# --- Форматирование для отображения ---
func format_release_for_display(version: String, changes: String, published: String) -> Dictionary:
	return {
		"version": version,
		"published": published,
		"changes": changes,
		"title": "v%s (%s)" % [version, published]
	}

# --- Очистка ресурсов ---
func cleanup() -> void:
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	print("[NewsParser] Очищены ресурсы")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()
