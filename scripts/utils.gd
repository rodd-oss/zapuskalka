extends Node

func fetch(url: String, params: FetchParams = null) -> FetchResult:
	var method := params.method if params else HTTPClient.METHOD_GET
	var headers := params.headers if params else PackedStringArray()
	var payload := params.payload if params else ""

	var http := HTTPRequest.new()
	http.name = "fetch"
	add_child(http)

	var res := FetchResult.new()

	var progress_timer: Timer
	if params and params.progress_callback.is_valid():
		progress_timer = Timer.new()
		progress_timer.name = "fetch_progress_watcher"
		progress_timer.wait_time = 0.1
		progress_timer.timeout.connect(
			_http_progress_timer_timed_out.bind(http, params.progress_callback),
		)
		add_child(progress_timer)

	while true:
		var err := http.request(url, headers, method, payload)
		if err != OK:
			res.error = err
			break

		if progress_timer:
			progress_timer.start()

		var args: Variant = await http.request_completed
		res.response_error = args[0]
		res.response_code = args[1]
		res.raw_headers = args[2]
		res.body = args[3]

		break

	if progress_timer:
		progress_timer.paused = true
		progress_timer.queue_free()

	http.queue_free()

	return res


func _http_progress_timer_timed_out(http: HTTPRequest, callback: Callable):
	callback.call(http.get_downloaded_bytes(), http.get_body_size())


class FetchParams:
	var method: HTTPClient.Method
	var headers: PackedStringArray
	var payload: String
	var progress_callback: Callable


	func _init(
			in_method: HTTPClient.Method = HTTPClient.METHOD_GET,
			in_payload: String = "",
			in_headers: PackedStringArray = PackedStringArray(),
			in_progress_callback: Callable = Callable(),
	) -> void:
		self.method = in_method
		self.headers = in_headers
		self.payload = in_payload
		self.progress_callback = in_progress_callback


class FetchResult:
	var error: int
	var response_error: int
	var response_code: int
	var raw_headers: PackedStringArray
	var body: PackedByteArray


func parse_headers(
		raw_headers: PackedStringArray,
		keys_in_lowercase: bool = false,
) -> Dictionary[String, PackedStringArray]:
	var dict: Dictionary[String, PackedStringArray] = { }

	for row: String in raw_headers:
		var kv: PackedStringArray = row.split(":", true, 1)
		var key := kv[0].to_lower() if keys_in_lowercase else kv[0]
		var vals := kv[1].split(",")
		for i: int in range(vals.size()):
			vals[i] = vals[i].strip_edges()

		var existing = dict.get(key)
		if existing:
			existing.append_array(vals)
		else:
			dict.set(key, vals)

	return dict


## result is return value of http.request
func http_request_error_text(result: int) -> StringName:
	match result:
		OK:
			return &"OK"
		ERR_UNCONFIGURED:
			return &"ERR_UNCONFIGURED"
		ERR_BUSY:
			return &"ERR_BUSY"
		ERR_INVALID_PARAMETER:
			return &"ERR_INVALID_PARAMETER"
		ERR_CANT_CONNECT:
			return &"ERR_CANT_CONNECT"
		_:
			return &"???"


## result is result from signal http.request_completed
func http_request_result_text(result: int) -> StringName:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return &"SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return &"CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return &"CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return &"CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return &"CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return &"TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return &"NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return &"BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return &"BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return &"REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return &"DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return &"DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return &"REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return &"TIMEOUT"
		_:
			return &"???"


func get_human_readable_byte_size(byte_size: int) -> String:
	if byte_size < 1024:
		return "%d B" % byte_size

	if byte_size < 1024 ** 2:
		return "%.2f KB" % (byte_size / 1024.0)

	if byte_size < 1024 ** 3:
		return "%.2f MB" % (byte_size / 1024.0 ** 2)

	if byte_size < 1024 ** 4:
		return "%.2f GB" % (byte_size / 1024.0 ** 3)

	if byte_size < 1024 ** 5:
		return "%.2f TB" % (byte_size / 1024.0 ** 4)

	if byte_size < 1024 ** 6:
		return "%.2f PB" % (byte_size / 1024.0 ** 5)

	if byte_size < 1024 ** 7:
		return "%.2f EB" % (byte_size / 1024.0 ** 6)

	if byte_size < 1024 ** 8:
		return "%.2f ZB" % (byte_size / 1024.0 ** 7)

	if byte_size < 1024 ** 9:
		return "%.2f YB" % (byte_size / 1024.0 ** 8)

	return "TOO MUCH"


## pass negative value to get text pointing to past
func get_human_readable_duration(secs: float) -> String:
	var v: float
	var s: String
	var neg := secs < 0.0

	if neg:
		secs = -secs

	if secs < 60.0:
		v = secs
		s = tr(&"duration_seconds").format(["%.0f" % v], &"{}")
	elif secs < 60.0 * 60.0:
		v = secs / 60.0
		s = tr(&"duration_minutes").format(["%.0f" % v], &"{}")
	elif secs < 60.0 * 60.0 * 24.0:
		v = secs / 60.0 / 60.0
		s = tr(&"duration_hours").format(["%.1f" % v], &"{}")
	elif secs < 60.0 * 60.0 * 24.0 * 7.0:
		v = secs / 60.0 / 60.0 / 24.0
		s = tr(&"duration_days").format(["%.1f" % v], &"{}")
	elif secs < 60.0 * 60.0 * 24.0 * 7.0 * 30.0:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0
		s = tr(&"duration_weeks").format(["%.1f" % v], &"{}")
	elif secs < 60.0 * 60.0 * 24.0 * 7.0 * 30.0 * 12.0:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0 / 30.0
		s = tr(&"duration_months").format(["%.1f" % v], &"{}")
	else:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0 / 30.0 / 12.0
		s = tr(&"duration_years").format(["%.1f" % v], &"{}")

	return tr(&"time_diff_ago").format([s], &"{}") if neg else s


func get_file_error_text(error: int) -> StringName:
	match error:
		ERR_FILE_NOT_FOUND:
			return &"NOT_FOUND"
		ERR_FILE_BAD_DRIVE:
			return &"BAD_DRIVE"
		ERR_FILE_BAD_PATH:
			return &"BAD_PATH"
		ERR_FILE_NO_PERMISSION:
			return &"NO_PERMISSION"
		ERR_FILE_ALREADY_IN_USE:
			return &"ALREADY_IN_USE"
		ERR_FILE_CANT_OPEN:
			return &"CANT_OPEN"
		ERR_FILE_CANT_WRITE:
			return &"CANT_WRITE"
		ERR_FILE_CANT_READ:
			return &"CANT_READ"
		ERR_FILE_UNRECOGNIZED:
			return &"UNRECOGNIZED"
		ERR_FILE_CORRUPT:
			return &"CORRUPT"
		ERR_FILE_MISSING_DEPENDENCIES:
			return &"MISSING_DEPENDENCIES"
		ERR_FILE_EOF:
			return &"EOF"
		_:
			return &"???"


func show_popup_message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

	await dialog.close_requested

	dialog.hide()
	dialog.queue_free()
