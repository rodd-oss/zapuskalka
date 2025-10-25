extends Node
class_name ServerMonitor


# --[ CONSTANTS ]--
const SERVER_ADDRESS := "gigabuh.d.roddtech.ru"
const SERVER_PORT := 25445
const CHECK_TIMEOUT := 10.0
const CACHE_DURATION := 180.0
const MAX_CONNECT_RETRIES := 3


# --[ STATE ]--
var _server_status := "unknown"
var _last_check_time := 0.0
var _check_count := 0


# --[ SIGNALS ]--
signal status_changed(new_status: String)


func _init() -> void:
	print("[ServerMonitor] Инициализирован для %s:%d" % [SERVER_ADDRESS, SERVER_PORT])
	print("[ServerMonitor] Проверка будет выполняться раз в 3 минуты")


# --- Проверка статуса сервера ---
func check_server_status() -> String:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - _last_check_time < CACHE_DURATION and _server_status != "unknown":
		print("[ServerMonitor] Кеш активен (%d сек осталось), статус: %s" % [int(CACHE_DURATION - (current_time - _last_check_time)), _server_status])
		return _server_status
	
	_last_check_time = current_time
	_check_count += 1
	
	print("[ServerMonitor] Проверка #%d начата (текущее время: %s)" % [_check_count, Time.get_datetime_string_from_system()])
	
	var tcp = StreamPeerTCP.new()
	print("[ServerMonitor] Попытка подключиться (1 сек макс)...")
	
	var error = tcp.connect_to_host(SERVER_ADDRESS, SERVER_PORT)
	
	if error != OK:
		print("[ServerMonitor] Ошибка подключения: %d" % error)
		_set_status("offline")
		return "offline"
	
	var wait_time = 0.0
	var max_wait = 1.0  
	
	while wait_time < max_wait:
		tcp.poll()
		var peer_status = tcp.get_status()
		
		match peer_status:
			StreamPeerTCP.STATUS_CONNECTED:
				print("[ServerMonitor]  ОНЛАЙН! (за %.2f сек)" % wait_time)
				tcp.disconnect_from_host()
				_set_status("online")
				return "online"
			
			StreamPeerTCP.STATUS_NONE:
				print("[ServerMonitor] ОФЛАЙН (%.2f сек)" % wait_time)
				tcp.disconnect_from_host()
				_set_status("offline")
				return "offline"
			
			StreamPeerTCP.STATUS_CONNECTING:
				wait_time += 0.01
				for _i in range(100):
					pass
				continue
		
		wait_time += 0.01
	
	# Если timeout - закрываем и считаем офлайн
	print("[ServerMonitor] TIMEOUT (1 сек) - сервер не ответил вовремя")
	tcp.disconnect_from_host() 
	_set_status("offline")
	return "offline"


func _set_status(new_status: String) -> void:
	if _server_status != new_status:
		_server_status = new_status
		status_changed.emit(new_status)
		print("[ServerMonitor] Статус ИЗМЕНИЛСЯ: %s → %s (проверка #%d)" % ["old", new_status, _check_count])


func get_status() -> String:
	return _server_status
