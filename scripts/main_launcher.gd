extends Control

## Main Launcher UI Controller (new design). Legacy scene удалена.
## NOTE: Используем явные пути через $ вместо сокращения %Name (несовместимость с вашей версией движка вызвала ошибки).

# Sidebar buttons
@onready var sidebar_home_btn: Button = $ContentHBox/Sidebar/VBoxContainer/HomeButton
@onready var sidebar_news_btn: Button = $ContentHBox/Sidebar/VBoxContainer/NewsButton
@onready var sidebar_settings_btn: Button = $ContentHBox/Sidebar/VBoxContainer/SettingsButton
@onready var sidebar_community_btn: Button = $ContentHBox/Sidebar/VBoxContainer/CommunityButton
@onready var sidebar_achievements_btn: Button = $ContentHBox/Sidebar/VBoxContainer/AchievementsButton
@onready var sidebar_mods_btn: Button = $ContentHBox/Sidebar/VBoxContainer/ModsButton

# Header controls
@onready var play_button: Button = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/ActionsHBox/PlayButton
@onready var update_button: Button = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/ActionsHBox/UpdateButton
@onready var progress_bar: ProgressBar = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/ActionsHBox/ProgressBar
@onready var current_version_label: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/VersionInfoHBox/CurrentVersionLabel
@onready var last_played_label: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/VersionInfoHBox/LastPlayedLabel
@onready var status_label: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/StatusLabel
@onready var game_description_label: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/GameDescription
@onready var game_title_label: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/GameTitle
@onready var tag_open_source: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/TagsHBox/OpenSourceTag
@onready var tag_engine: Label = $ContentHBox/MainArea/GameHeader/OverlayVBox/VBoxContainer/TagsHBox/EngineTag
@onready var background_image: TextureRect = $ContentHBox/MainArea/GameHeader/BackgroundImage

# Content panels
@onready var news_panel: Control = $ContentHBox/MainArea/NewsPanel
@onready var settings_panel: Control = $ContentHBox/MainArea/SettingsPanel
@onready var news_grid: GridContainer = $ContentHBox/MainArea/NewsPanel/VBoxContainer/NewsGrid
@onready var news_card_template: Panel = $ContentHBox/MainArea/NewsPanel/VBoxContainer/NewsGrid/NewsCardTemplate
@onready var changelog_rich_text: RichTextLabel = $ContentHBox/MainArea/NewsPanel/VBoxContainer/ChangelogRichText

var update_manager: Node
var _current_tab: String = "home" # home | news | settings
var _news_data: Array[Dictionary] = []
var _last_played_iso: String = "" # could be persisted later

func _ready() -> void:
	_init_update_manager()
	_connect_ui()
	_seed_news_data()
	_rebuild_news_cards()
	_switch_tab("home")
	game_title_label.text = "Epic Adventure Awaits"
	game_description_label.text = "Отправляйтесь в невероятное путешествие через фантастические миры. Исследуйте, сражайтесь и создавайте свою легенду."
	tag_open_source.text = "Open Source"
	tag_engine.text = "Godot Engine"
	_tint_background()
	status_label.text = "Инициализация..."
	progress_bar.value = 0
	update_button.disabled = true
	play_button.disabled = true

func _init_update_manager() -> void:
	update_manager = load("res://scripts/update_manager.gd").new()
	add_child(update_manager)
	update_manager.status_changed.connect(_on_status_changed)
	update_manager.progress_changed.connect(_on_progress_changed)
	update_manager.versions_known.connect(_on_versions_known)
	update_manager.update_available.connect(_on_update_available)
	update_manager.update_finished.connect(_on_update_finished)
	update_manager.changelog_received.connect(_on_changelog_received)
	update_manager.start_check()

func _connect_ui() -> void:
	sidebar_home_btn.pressed.connect(func(): _switch_tab("home"))
	sidebar_news_btn.pressed.connect(func(): _switch_tab("news"))
	sidebar_settings_btn.pressed.connect(func(): _switch_tab("settings"))
	# Additional sidebar buttons currently placeholders
	play_button.pressed.connect(_on_play_pressed)
	update_button.pressed.connect(_on_update_pressed)

func _seed_news_data() -> void:
	# Placeholder data; replace later with API / JSON.
	_news_data = [
		{
			"title": "Обновление 1.2.3: Новые локации и персонажи",
			"excerpt": "Три новые локации, пять героев и ветка квестов...",
			"age": "2 дн назад",
			"likes": 234, "comments": 45,
		},
		{
			"title": "Сезонное событие: Зимний фестиваль",
			"excerpt": "Эксклюзивные награды, новые квесты и ледяные монстры...",
			"age": "5 дн назад",
			"likes": 456, "comments": 78,
		},
		{
			"title": "Исправления и оптимизация производительности",
			"excerpt": "+30% FPS, фиксы критических багов и улучшенный ИИ",
			"age": "1 нед назад",
			"likes": 189, "comments": 23,
		},
	]

func _rebuild_news_cards() -> void:
	if news_card_template == null:
		return
	# Clear previous (except template)
	for child in news_grid.get_children():
		if child != news_card_template:
			child.queue_free()
	news_card_template.visible = false
	for data in _news_data:
		var card: Panel = news_card_template.duplicate() as Panel
		card.visible = true
		news_grid.add_child(card)
		# Child lookup by expected names (define these inside template): TitleLabel, ExcerptLabel, MetaLabel
		var title_label: Label = card.get_node_or_null("TitleLabel")
		var excerpt_label: Label = card.get_node_or_null("ExcerptLabel")
		var meta_label: Label = card.get_node_or_null("MetaLabel")
		if title_label: title_label.text = data.get("title", "")
		if excerpt_label: excerpt_label.text = data.get("excerpt", "")
		if meta_label: meta_label.text = "%s  |  ❤ %d  💬 %d" % [data.get("age", ""), data.get("likes", 0), data.get("comments", 0)]

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	# Home == show header + news panel (already) — header always visible; toggle news/settings panels
	if news_panel: news_panel.visible = (tab in ["home", "news"])
	if settings_panel: settings_panel.visible = (tab == "settings")
	# Update sidebar highlight (optionally by adding a selected stylebox later)

func _tint_background() -> void:
	if background_image and background_image.texture:
		background_image.modulate = Color(1,1,1,0.95)

## Update Manager Signal Handlers ##

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_progress_changed(pct: float) -> void:
	progress_bar.value = pct

func _on_versions_known(local_v: String, remote_v: String) -> void:
	current_version_label.text = "v%s" % remote_v
	# Allow play if we have executable and not downloading
	if not update_manager.is_downloading():
		play_button.disabled = false

func _on_update_available(new_version: String) -> void:
	update_button.disabled = false
	play_button.disabled = true
	status_label.text = "Доступно обновление v%s" % new_version

func _on_update_finished(success: bool, message: String) -> void:
	status_label.text = message
	update_button.disabled = true
	var have_exe = update_manager.get_game_executable_path() != ""
	play_button.disabled = not have_exe
	if success:
		_last_played_iso = Time.get_datetime_string_from_system()
		last_played_label.text = "Обновлено: %s" % _last_played_iso

func _on_changelog_received(text_bbcode: String) -> void:
	if changelog_rich_text:
		changelog_rich_text.clear()
		changelog_rich_text.append_bbcode(text_bbcode)

## User Actions ##

func _on_update_pressed() -> void:
	update_button.disabled = true
	update_manager.download_and_apply_update()

func _on_play_pressed() -> void:
	var exe_path: String = update_manager.get_game_executable_path()
	if exe_path.is_empty():
		status_label.text = "Исполняемый файл не найден"
		return
	status_label.text = "Запуск игры..."
	var pid = OS.create_process(exe_path, [])
	if pid <= 0:
		status_label.text = "Ошибка запуска"
	else:
		status_label.text = "Игра запущена (PID %d)" % pid
		# Optionally quit launcher: get_tree().quit()

## Public helper for future persistence (not yet saving to disk) ##

func get_last_played_iso() -> String:
	return _last_played_iso
