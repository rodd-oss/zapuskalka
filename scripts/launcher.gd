extends Control


@onready var settings_panel: Panel = $MainContainer/ContentContainer/SettingsPanel
@onready var news_section: Panel = $MainContainer/ContentContainer/NewsSection
@onready var sidebar: Panel = $MainContainer/Sidebar
@onready var header: Panel = $Header
@onready var footer: Panel = $Footer
@onready var webview = $WebView


func _ready() -> void:
	# Здесь можно инициализировать UI, загрузить новости, применить настройки и т.д.
	# Подключаем обработчик логов из JS через godot_wry bridge
	webview.bind("godot_log", _on_js_log)

func _on_js_log(msg):
	print("[JS]", msg)

func toggle_settings_panel() -> void:
	settings_panel.visible = not settings_panel.visible
