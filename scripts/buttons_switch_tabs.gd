extends TabContainer

@export var buttons_group: ButtonGroup


func _ready() -> void:
	buttons_group.pressed.connect(_on_group_button_pressed)
	tab_changed.connect(_on_tab_changed)

	_update_pressed_button()


func _on_group_button_pressed(button: BaseButton) -> void:
	var new_tab_index: int = button.get_meta("tab_index", -1)
	if new_tab_index >= 0:
		current_tab = new_tab_index


func _on_tab_changed(_tab_index: int) -> void:
	_update_pressed_button()


func _update_pressed_button() -> void:
	for btn: BaseButton in buttons_group.get_buttons():
		if btn.get_meta("tab_index", -1) == current_tab:
			btn.button_pressed = true
			break
