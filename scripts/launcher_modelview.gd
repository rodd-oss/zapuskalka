class_name LauncherModelView
extends PanelContainer

@onready var game_status_tab_container: TabContainer = %GameStatusesTabs
@onready var page_main: Control = %PageMain
@onready var page_news: Control = %PageNews
@onready var page_preferences: Control = %PagePreferences
@onready var page_community: Control = %PageCommunity
@onready var page_achievments: Control = %PageAchievments
@onready var page_mods: Control = %PageMods

# Main page
@onready var primary_action_tabs: TabContainer = %PageMain/ % PrimaryActionTabs # hello formatter?
@onready var button_play: Button = %PageMain/ % PlayButton
@onready var button_stop: Button = %PageMain/ % StopButton
@onready var button_update: Button = %PageMain/ % UpdateButton
@onready var button_download: Button = %PageMain/ % DownloadButton
@onready var label_installed_version: Label = %PageMain/ % InstalledVersion
@onready var label_last_play_time: Label = %PageMain/ % LastPlayTime
@onready var label_total_play_time: Label = %PageMain/ % TotalPlayTime

var game_status: GameStatus:
	get:
		return game_status_tab_container.current_tab as GameStatus
	set(val):
		game_status_tab_container.current_tab = val

var game_runnable: bool:
	set(val):
		game_runnable = val
		button_play.disabled = not game_runnable

var installed_version_name: String:
	set(val):
		installed_version_name = val
		label_installed_version.text = installed_version_name

var primary_action: PrimaryAction:
	get:
		return primary_action_tabs.current_tab as PrimaryAction
	set(val):
		primary_action_tabs.current_tab = val

var primary_action_enabled: bool:
	set(val):
		button_play.disabled = not val
		button_stop.disabled = not val
		button_update.disabled = not val
		button_download.disabled = not val

var last_playtime: String:
	get:
		return label_last_play_time.text
	set(val):
		label_last_play_time.text = val

var total_playtime: String:
	get:
		return label_total_play_time.text
	set(val):
		label_total_play_time.text = val

signal play_requested()
signal stop_requested()
signal update_requested()
signal download_requested()


func _ready() -> void:
	button_play.pressed.connect(play_requested.emit)
	button_stop.pressed.connect(stop_requested.emit)
	button_update.pressed.connect(update_requested.emit)
	button_download.pressed.connect(download_requested.emit)


func _get_game_status_control(status: GameStatus) -> Control:
	return game_status_tab_container.get_child(status)


func set_game_status_subtext(status: GameStatus, subtext: String) -> void:
	var status_control := _get_game_status_control(status)
	if not status_control:
		return

	var subtext_control := status_control.get_node_or_null("%SubText") as Label
	if subtext_control:
		subtext_control.text = subtext


func set_downloading_progress(current: int, total: int) -> void:
	@warning_ignore("integer_division")
	var pct := (current * 100 / total) if total != 0 else 100
	set_game_status_subtext(GameStatus.UPDATING, "%d%%" % pct)

# Child controls must be in same order as in %GameStatusesTabs
enum GameStatus {
	CHECKING_FOR_UPDATE,
	UPDATE_NEEDED,
	DOWNLOAD_NEEDED,
	UPDATING,
	READY,
	ERROR_UPDATING,
}

# Child controls must be in same order as in %PrimaryActionTabs
enum PrimaryAction {
	PLAY,
	SHUTDOWN,
	UPDATE,
	DOWNLOAD,
}
