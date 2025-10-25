# Файл: res://scripts/ServerStatusIndicator.gd
extends ColorRect

var _animation_time := 0.0
var _current_status := "unknown"


func _ready() -> void:
	_update_indicator("unknown")


func _process(delta: float) -> void:
	_animation_time += delta
	queue_redraw()  # Вызываем перерисовку каждый фрейм


func set_status(new_status: String) -> void:
	if _current_status != new_status:
		_current_status = new_status
		_update_indicator(new_status)


func _update_indicator(new_status: String) -> void:
	match new_status:
		"online":
			color = Color.GREEN
			tooltip_text = " Сервер онлайн"
		"offline":
			color = Color.RED
			tooltip_text = " Сервер офлайн"
		"error":
			color = Color.YELLOW
			tooltip_text = " Ошибка"
		_:
			color = Color.GRAY
			tooltip_text = " Проверяется..."


func _draw() -> void:
	var rect_size = get_rect().size
	var center = rect_size / 2
	var radius = min(rect_size.x, rect_size.y) / 2 - 2
	
	# Рисуем круг с пульсацией если проверяется
	if _current_status == "unknown":
		# Пульсирующий эффект для статуса "проверяется"
		var pulse = sin(_animation_time * 3.0) * 0.3 + 0.7
		var pulse_color = color * Color(1, 1, 1, pulse)
		draw_circle(center, radius, pulse_color)
	else:
		# Плотный круг для других статусов
		draw_circle(center, radius, color)
	
	# Внутренний кружок для глубины
	draw_circle(center, radius - 2, color.darkened(0.3))
