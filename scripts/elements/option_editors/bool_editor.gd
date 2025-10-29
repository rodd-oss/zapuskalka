class_name BoolEditor
extends BaseOptionEditor

@onready var name_label: Label = get_node("%Name")
@onready var check_box: CheckBox = get_node("%Value")


func _ready() -> void:
	check_box.toggled.connect(value_changed.emit.unbind(1))


func set_property_name(prop_name: String):
	if not name_label:
		name_label = get_node("%Name")
		if not name_label:
			return

	name_label.text = prop_name


func set_property_value(value: Variant):
	if not check_box:
		check_box = get_node("%Value")
		if not check_box:
			return

	check_box.button_pressed = value as bool


func get_property_value() -> Variant:
	return check_box.button_pressed
