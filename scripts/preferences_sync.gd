class_name PreferencesSync
extends Control

## export variables using `@export_custom(PROPERTY_HINT_DONT_RENDER, "")`
## and this variable will not be visible in preferences page
const PROPERTY_HINT_DONT_RENDER = PROPERTY_HINT_MAX + 1

@onready var option_list: Container = %OptionList

var _have_changes := false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_populate_option_editors()


func _on_visibility_changed() -> void:
	if visible:
		_push_values_to_editors()
		# in case if some properties have validation code
		_pull_values_from_editors()
		_have_changes = false
	else:
		if _have_changes:
			LauncherPreferences.instance.save()


const SKIPPED_PROPERTY_NAMES = [
	&"resource_local_to_scene",
	&"resource_name",
	&"script",
	# &"installed_release_tag",
	# &"installed_app_path",
]


func _push_values_to_editors() -> void:
	for child_idx: int in range(option_list.get_child_count()):
		var editor := option_list.get_child(child_idx) as BaseOptionEditor
		if not editor:
			continue

		var prop_name := editor.get_meta(&"prop_name") as StringName
		var prop_val: Variant = LauncherPreferences.instance.get(prop_name)

		editor.set_property_value(prop_val)


func _pull_values_from_editors() -> void:
	for child_idx: int in range(option_list.get_child_count()):
		var editor := option_list.get_child(child_idx) as BaseOptionEditor
		if not editor:
			continue

		var prop_name := editor.get_meta(&"prop_name") as StringName
		var prop_new_val: Variant = editor.get_property_value()

		LauncherPreferences.instance.set(prop_name, prop_new_val)


func _populate_option_editors() -> void:
	var prefs := LauncherPreferences.instance

	var props := prefs.get_property_list()
	for prop: Dictionary in props:
		if (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
			continue

		if (prop.hint & PROPERTY_HINT_DONT_RENDER) != 0:
			continue

		if prop.name in SKIPPED_PROPERTY_NAMES:
			continue

		var prop_name := prop.name as StringName
		var prop_editor := _create_property_editor(prop)
		if not prop_editor:
			continue

		var prop_value: Variant = prefs.get(prop.name)

		prop_editor.set_meta(&"prop_name", prop_name)
		prop_editor.name = prop_name
		prop_editor.set_property_name("launcher_option_%s" % prop_name)
		prop_editor.set_property_value(prop_value)
		prop_editor.value_changed.connect(_on_editor_value_changed.bind(prop_editor))

		option_list.add_child(prop_editor)


func _on_editor_value_changed(editor: BaseOptionEditor) -> void:
	var prop_name := editor.get_meta(&"prop_name") as StringName
	var val_to_set: Variant = editor.get_property_value()

	LauncherPreferences.instance.set(prop_name, val_to_set)

	var new_val: Variant = LauncherPreferences.instance.get(prop_name)
	if new_val != val_to_set:
		editor.set_property_value(new_val)

	_have_changes = true


const EDITORS_SCENE_PATH_PATTERN = "res://scenes/elements/option_editors/%s_editor.tscn"


func _create_property_editor(prop: Dictionary) -> BaseOptionEditor:
	var scene_path := EDITORS_SCENE_PATH_PATTERN % _get_prop_type_name(prop)
	var control_scene := load(scene_path) as PackedScene
	if control_scene == null:
		return null

	var control := control_scene.instantiate()
	var option_editor := control as BaseOptionEditor
	if not option_editor:
		push_error(
			"scene root doesn't have attached script inherited " +
			"from 'BaseOptionEditor' (scene '%s')" % scene_path,
		)
		control.queue_free()
		return null

	return control


func _get_prop_type_name(prop: Dictionary) -> StringName:
	match prop.type:
		TYPE_OBJECT:
			return prop.class_name
		TYPE_NIL:
			return &"null"
		TYPE_BOOL:
			return &"bool"
		TYPE_INT:
			return &"int"
		TYPE_FLOAT:
			return &"float"
		TYPE_STRING:
			return &"String"
		TYPE_VECTOR2:
			return &"Vector2"
		TYPE_VECTOR2I:
			return &"Vector2i"
		TYPE_RECT2:
			return &"Rect2"
		TYPE_RECT2I:
			return &"Rect2i"
		TYPE_VECTOR3:
			return &"Vector3"
		TYPE_VECTOR3I:
			return &"Vector3i"
		TYPE_TRANSFORM2D:
			return &"Transform2D"
		TYPE_VECTOR4:
			return &"Vector4"
		TYPE_VECTOR4I:
			return &"Vector4i"
		TYPE_PLANE:
			return &"Plane"
		TYPE_QUATERNION:
			return &"Quaternion"
		TYPE_AABB:
			return &"AABB"
		TYPE_BASIS:
			return &"Basis"
		TYPE_TRANSFORM3D:
			return &"Transform3D"
		TYPE_PROJECTION:
			return &"Projection"
		TYPE_COLOR:
			return &"Color"
		TYPE_STRING_NAME:
			return &"StringName"
		TYPE_NODE_PATH:
			return &"NodePath"
		TYPE_RID:
			return &"RID"
		TYPE_OBJECT:
			return &"Object"
		TYPE_CALLABLE:
			return &"Callable"
		TYPE_SIGNAL:
			return &"Signal"
		TYPE_DICTIONARY:
			return &"Dictionary"
		TYPE_ARRAY:
			return &"Array"
		TYPE_PACKED_BYTE_ARRAY:
			return &"PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			return &"PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return &"PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			return &"PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return &"PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			return &"PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return &"PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return &"PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			return &"PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY:
			return &"PackedVector4Array"
		_:
			return &"???"
