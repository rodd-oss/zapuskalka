class_name StringEditor
extends BaseOptionEditor

@onready var name_label: Label = get_node("%Name")
@onready var value_edit: LineEdit = get_node("%Value")


func _ready() -> void:
	value_edit.text_changed.connect(value_changed.emit.unbind(1))


func set_property_name(prop_name: String):
	if not name_label:
		name_label = get_node("%Name")
		if not name_label:
			return

	name_label.text = prop_name


func set_property_value(value: Variant):
	if not value_edit:
		value_edit = get_node("%Value")
		if not value_edit:
			return

	value_edit.text = value as String


func get_property_value() -> Variant:
	return value_edit.text
