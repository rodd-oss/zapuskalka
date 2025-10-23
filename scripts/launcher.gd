extends Control

@onready var settings_panel: Panel = $MainContainer/ContentContainer/SettingsPanel
@onready var news_section: Panel = $MainContainer/ContentContainer/NewsSection
@onready var sidebar: Panel = $MainContainer/Sidebar
@onready var header: Panel = $Header
@onready var footer: Panel = $Footer

func _ready() -> void:
	# Здесь можно инициализировать UI, загрузить новости, применить настройки и т.д.
	pass

func toggle_settings_panel() -> void:
	settings_panel.visible = not settings_panel.visible
