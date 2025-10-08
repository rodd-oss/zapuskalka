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

# Content panels
@onready var news_panel: Control = $ContentHBox/MainArea/NewsPanel
@onready var settings_panel: Control = $ContentHBox/MainArea/SettingsPanel
@onready var changelog_rich_text: RichTextLabel = $ContentHBox/MainArea/NewsPanel/VBoxContainer/ChangelogRichText

var update_manager: Node
var _current_tab: String = "home" # home | news | settings
var _last_played_iso: String = "" # could be persisted later
var _sidebar_buttons: Array[Button] = []
var _active_btn_style: StyleBox
var _inactive_btn_style: StyleBox

func _ready() -> void:
	_init_update_manager()
	_connect_ui()
	_cache_sidebar_buttons()
	# Removed news cards; only changelog remains
	_switch_tab("home")
	game_title_label.text = "Epic Battle Awaits"
	game_description_label.text = "GIGABUH LAUNCHER"
	tag_open_source.text = "Open Source"
	tag_engine.text = "Godot Engine"
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

func _cache_sidebar_buttons() -> void:
	_sidebar_buttons = [sidebar_home_btn, sidebar_news_btn, sidebar_settings_btn, sidebar_community_btn, sidebar_achievements_btn, sidebar_mods_btn]
	if sidebar_home_btn.theme and sidebar_home_btn.theme.has_stylebox("focus", "Button"):
		_active_btn_style = sidebar_home_btn.theme.get_stylebox("focus", "Button")
	# Clone normal stylebox for inactive fallback
	if sidebar_home_btn.theme and sidebar_home_btn.theme.has_stylebox("normal", "Button"):
		_inactive_btn_style = sidebar_home_btn.theme.get_stylebox("normal", "Button").duplicate()
	# Force play button text color (white over dark primary) to avoid theme swaps losing contrast
	play_button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.99))

func _seed_news_data() -> void:
	pass # no-op currently (news disabled)
func _rebuild_news_cards() -> void:
	pass

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	# Home == show header + news panel (already) — header always visible; toggle news/settings panels
	if news_panel: news_panel.visible = (tab in ["home", "news"])
	if settings_panel: settings_panel.visible = (tab == "settings")
	# Update sidebar highlight (optionally by adding a selected stylebox later)
	_update_sidebar_highlight(tab)

func _tint_background() -> void:
	pass # background image removed; kept method placeholder in case future gradient logic is added

func _update_sidebar_highlight(tab: String) -> void:
	var mapping := {
		"home": sidebar_home_btn,
		"news": sidebar_news_btn,
		"settings": sidebar_settings_btn,
		"community": sidebar_community_btn,
		"achievements": sidebar_achievements_btn,
		"mods": sidebar_mods_btn,
	}
	for b in _sidebar_buttons:
		if b == null:
			continue
		if mapping.get(tab) == b and _active_btn_style:
			b.add_theme_stylebox_override("normal", _active_btn_style)
		elif _inactive_btn_style:
			b.add_theme_stylebox_override("normal", _inactive_btn_style)

## Update Manager Signal Handlers ##

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_progress_changed(pct: float) -> void:
	progress_bar.value = pct
	progress_bar.visible = pct > 0.01 and pct < 100.0

func _on_versions_known(_local_v: String, remote_v: String) -> void:
	current_version_label.text = "v%s" % remote_v
	# Allow play if we have executable and not downloading
	if not update_manager.is_downloading():
		play_button.disabled = false

func _on_update_available(new_version: String) -> void:
	update_button.disabled = false
	play_button.disabled = true
	status_label.text = "Доступно обновление v%s" % new_version
	print("[Launcher] Update available:", new_version)
	progress_bar.visible = false

func _on_update_finished(success: bool, message: String) -> void:
	status_label.text = message
	update_button.disabled = true
	var have_exe = update_manager.get_game_executable_path() != ""
	play_button.disabled = not have_exe
	if success:
		_last_played_iso = Time.get_datetime_string_from_system()
		last_played_label.text = "Обновлено: %s" % _last_played_iso
	print("[Launcher] Update finished success=", success, " message=", message)
	progress_bar.visible = false

func _on_changelog_received(text_bbcode: String) -> void:
	if changelog_rich_text:
		changelog_rich_text.clear()
		changelog_rich_text.append_bbcode(text_bbcode)

## User Actions ##

func _on_update_pressed() -> void:
	print("[Launcher] Update button pressed")
	update_button.disabled = true
	update_button.text = "Обновление..."
	progress_bar.value = 0
	progress_bar.visible = true
	update_manager.download_and_apply_update()

func _on_play_pressed() -> void:
	print("[Launcher] Play button pressed")
	var exe_path: String = update_manager.get_game_executable_path()
	if exe_path.is_empty():
		status_label.text = "Исполняемый файл не найден"
		return
	status_label.text = "Запуск игры..."
	var pid = OS.create_process(exe_path, [])
	if pid <= 0:
		status_label.text = "Ошибка запуска"
		print("[Launcher] Failed to start game")
	else:
		status_label.text = "Игра запущена (PID %d)" % pid
		print("[Launcher] Game started PID=", pid)
		# Optionally quit launcher: get_tree().quit()

## Public helper for future persistence (not yet saving to disk) ##

func get_last_played_iso() -> String:
	return _last_played_iso
