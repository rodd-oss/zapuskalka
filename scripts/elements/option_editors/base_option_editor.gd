@abstract
class_name BaseOptionEditor
extends Control

@warning_ignore("unused_signal") # used in derived classes!
signal value_changed()


@abstract func set_property_name(prop_name: String)


@abstract func set_property_value(value: Variant)


@abstract func get_property_value() -> Variant
