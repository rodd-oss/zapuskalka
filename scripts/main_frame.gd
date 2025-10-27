extends PanelContainer

@onready var game_status_tab_container: TabContainer = %GameStatusesTabs

var game_status: GameStatus:
	get:
		return game_status_tab_container.current_tab as GameStatus
	set(val):
		game_status_tab_container.current_tab = val

var _prev_sec_test: int = 0


func _process(_delta: float) -> void:
	@warning_ignore("integer_division")
	var cur_sec := Time.get_ticks_msec() / 3000
	if cur_sec != _prev_sec_test:
		_prev_sec_test = cur_sec
		game_status = ((game_status + 1) % GameStatus.keys().size()) as GameStatus

	set_downloading_progress(Time.get_ticks_msec() % 3000, 3000)


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


enum GameStatus {
	CHECKING_FOR_UPDATE,
	UPDATE_NEEDED,
	UPDATING,
	READY,
	ERROR_UPDATING,
}
