class_name LauncherController
extends LauncherModelView

const GITHUB_API_CALL_INTERVAL_MS = 60 * 1000 # 60/hour
const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"
const GITHUB_API_ENDPOINT_LATEST_RELEASE := "https://api.github.com/repos/%s/%s/releases/latest"

const UPDATE_CHECK_MINIMUM_INTERVAL = 60.0

var state := LauncherState.START:
	set(new_state):
		var old_state := state
		state = new_state
		_state_transition(old_state, new_state)

var _github_ratelimit_remaining := 1
var _github_ratelimit_resettime := 0.0

var _release_tag_name: String
var _release_asset_json: Dictionary = { }
var _running_game_pid := -1
var _running_game_starttime := 0
var _running_game_playtime_at_start := 0
var _pending_play_request := false
var _pending_force_download := false
var _last_update_check_time := 0.0
var _last_pid_alive_check_time := 0.0


func _ready() -> void:
	super._ready()

	state = LauncherState.START

	play_requested.connect(_on_play_requested)
	stop_requested.connect(_on_stop_requested)
	update_requested.connect(_on_update_requested)
	download_requested.connect(_on_download_requested)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			LauncherPreferences.instance.save()


func _process(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()

	match state:
		LauncherState.PLAYING:
			if _running_game_pid < 0:
				state = LauncherState.END_PLAYING
			else:
				if _last_pid_alive_check_time + 1.0 < now:
					_last_pid_alive_check_time = now
					if not OS.is_process_running(_running_game_pid):
						_running_game_pid = -1
						state = LauncherState.END_PLAYING

	_update_play_times()


func _update_play_times() -> void:
	var now := Time.get_unix_time_from_system() as int

	if state == LauncherState.PLAYING:
		var play_session_duration_secs := now - _running_game_starttime
		var new_total_playtime := _running_game_playtime_at_start
		new_total_playtime += play_session_duration_secs
		LauncherPreferences.instance.total_play_time_secs = new_total_playtime

		last_playtime = &"last_play_time_now"
		LauncherPreferences.instance.last_play_unixtime = now
	else:
		var last_play_time_diff := LauncherPreferences.instance.last_play_unixtime - now
		last_playtime = Utils.get_human_readable_duration(last_play_time_diff)

	var total_play_time_str := LauncherPreferences.instance.total_play_time_secs
	total_playtime = Utils.get_human_readable_duration(total_play_time_str)

	pass


func _state_transition(old_state: LauncherState, new_state: LauncherState) -> void:
	print(
		"state transition %s -> %s" % [
			LauncherState.keys()[old_state],
			LauncherState.keys()[new_state],
		],
	)

	match new_state:
		LauncherState.START:
			installed_version_name = LauncherPreferences.instance.installed_release_tag
			if installed_version_name.is_empty():
				installed_version_name = "not_installed"

			state = LauncherState.INSTALLATION_CHECK
		LauncherState.INSTALLATION_CHECK:
			var app_path := LauncherPreferences.instance.installed_app_path

			if app_path.is_empty():
				state = LauncherState.NOT_INSTALLED
			elif not FileAccess.file_exists(app_path):
				# app file disappeared
				LauncherPreferences.instance.installed_app_path = ""
				LauncherPreferences.instance.installed_release_tag = ""
				state = LauncherState.INSTALLATION_CHECK
			else: # TODO: validate app file
				# app installed
				state = LauncherState.UPDATE_CHECK
		LauncherState.NOT_INSTALLED:
			game_status = GameStatus.DOWNLOAD_NEEDED
			primary_action = PrimaryAction.DOWNLOAD
		LauncherState.UPDATE_CHECK:
			game_status = GameStatus.CHECKING_FOR_UPDATE
			primary_action_enabled = false

			var json := await _fetch_latest_release_json()
			if "error" in json:
				game_status = GameStatus.ERROR_UPDATING
				set_game_status_subtext(GameStatus.ERROR_UPDATING, json.error)

				_pending_force_download = false # TODO: get rid of those global vars
				state = LauncherState.UPDATE_CHECK_ERROR
			else:
				_last_update_check_time = Time.get_unix_time_from_system()
				_release_tag_name = json.tag_name as String
				_release_asset_json = _find_asset_for_current_platform(json)

				if json.tag_name != LauncherPreferences.instance.installed_release_tag:
					# app outdated
					state = LauncherState.OUTDATED
				else:
					_pending_force_download = false
					if _pending_play_request:
						_pending_play_request = false
						state = LauncherState.PLAYING
					else:
						state = LauncherState.READY_TO_PLAY
		LauncherState.UPDATE_CHECK_ERROR:
			# mb dedicated button needed?
			primary_action = PrimaryAction.UPDATE
			primary_action_enabled = true
		LauncherState.OUTDATED:
			if LauncherPreferences.instance.update_automatically or _pending_force_download:
				_pending_force_download = false
				state = LauncherState.UPDATING
			else:
				game_status = GameStatus.UPDATE_NEEDED
				primary_action = PrimaryAction.UPDATE
				primary_action_enabled = true
		LauncherState.DOWNLOAD:
			# for now updating and downloading is same
			_pending_force_download = true
			state = LauncherState.UPDATE_CHECK
		LauncherState.UPDATING:
			game_status = GameStatus.UPDATING
			primary_action_enabled = false

			while true: # not a loop
				var asset_bytes := PackedByteArray()
				var err_text := await _fetch_asset(
					_release_asset_json,
					asset_bytes,
					_update_progress_callback,
				)
				if not err_text.is_empty():
					set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
					state = LauncherState.UPDATE_ERROR
					break

				var asset_store_dir := LauncherPreferences.instance.installation_path
				asset_store_dir = asset_store_dir.path_join(_release_tag_name)
				var asset_store_fpath := asset_store_dir.path_join(_release_asset_json.name)

				var err := DirAccess.make_dir_recursive_absolute(asset_store_dir)
				if err != OK:
					err_text = Utils.get_file_error_text(err)
					push_error("failed create directory for release: %s" % err_text)
					set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
					state = LauncherState.UPDATE_ERROR
					break

				var asset_file := FileAccess.open(asset_store_fpath, FileAccess.WRITE)
				if not asset_file:
					err_text = Utils.get_file_error_text(FileAccess.get_open_error())
					push_error("failed create asset file on disk: %s" % err_text)
					set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
					state = LauncherState.UPDATE_ERROR
					break

				if not asset_file.store_buffer(asset_bytes):
					err_text = Utils.get_file_error_text(asset_file.get_error())
					push_error("failed write to asset file on disk: error %d" % err_text)
					set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
					state = LauncherState.UPDATE_ERROR
					break

				LauncherPreferences.instance.installed_release_tag = _release_tag_name
				LauncherPreferences.instance.installed_app_path = asset_store_fpath
				LauncherPreferences.instance.save()
				state = LauncherState.UPDATED

				break # end of not a loop
		LauncherState.UPDATE_ERROR:
			game_status = GameStatus.ERROR_UPDATING
			primary_action = PrimaryAction.UPDATE
			primary_action_enabled = true
		LauncherState.UPDATED:
			installed_version_name = LauncherPreferences.instance.installed_release_tag

			if _pending_play_request:
				_pending_play_request = false
				state = LauncherState.PLAYING
			else:
				state = LauncherState.READY_TO_PLAY
		LauncherState.READY_TO_PLAY:
			game_status = GameStatus.READY
			primary_action = PrimaryAction.PLAY
			primary_action_enabled = true
		LauncherState.PLAYING:
			var now := Time.get_unix_time_from_system()
			if now > _last_update_check_time + UPDATE_CHECK_MINIMUM_INTERVAL:
				state = LauncherState.UPDATE_CHECK
			else:
				primary_action_enabled = false

				var app_path := LauncherPreferences.instance.installed_app_path
				var app_system_path := ProjectSettings.globalize_path(app_path)
				_running_game_pid = OS.create_process(app_system_path, [])

				if _running_game_pid < 0:
					await Utils.show_popup_message("popup_gamelaunch_error_title", "popup_gamelaunch_error_text")
					return

				_running_game_starttime = now as int
				_running_game_playtime_at_start = LauncherPreferences.instance.total_play_time_secs

				primary_action = PrimaryAction.SHUTDOWN

				await get_tree().create_timer(2.0).timeout

				primary_action_enabled = true
		LauncherState.END_PLAYING:
			state = LauncherState.READY_TO_PLAY
		_:
			push_error("unhandled launcher state entry %s" % LauncherState.keys()[new_state])


var _speed_sample_time := 0
var _speed_sample_prevsize := 0


func _update_progress_callback(downloaded_bytes: int, total_bytes: int):
	var now := Time.get_ticks_msec()
	var time_window := now - _speed_sample_time
	var size_window := downloaded_bytes - _speed_sample_prevsize
	var byte_per_sec := int(size_window / (time_window / 1000.0))
	var speed_text := "%s/s" % Utils.get_human_readable_byte_size(byte_per_sec)

	_speed_sample_time = now
	_speed_sample_prevsize = downloaded_bytes

	if total_bytes < 0:
		set_game_status_subtext(GameStatus.UPDATING, speed_text)
	else:
		@warning_ignore("integer_division")
		var pct := 100.0 * downloaded_bytes / total_bytes
		set_game_status_subtext(GameStatus.UPDATING, "%.1f%% (%s)" % [pct, speed_text])


func _on_play_requested() -> void:
	print("play requested")

	match state:
		LauncherState.READY_TO_PLAY:
			_pending_play_request = true
			state = LauncherState.PLAYING


func _on_stop_requested() -> void:
	print("stop requested")

	if _running_game_pid < 0:
		return

	var err := OS.kill(_running_game_pid)
	if err:
		push_error("OS.kill => %d" % err)
		await Utils.show_popup_message("popup_gamekill_error_title", "popup_gamekill_error_text")
		return


func _on_update_requested() -> void:
	print("update requested")

	match state:
		LauncherState.UPDATE_CHECK_ERROR:
			state = LauncherState.UPDATE_CHECK
		LauncherState.OUTDATED:
			if _update_check_was_long_ago() or _release_asset_json.is_empty():
				state = LauncherState.UPDATE_CHECK
			else:
				state = LauncherState.UPDATING


func _on_download_requested() -> void:
	print("download requested")

	match state:
		LauncherState.NOT_INSTALLED:
			state = LauncherState.DOWNLOAD


func _find_asset_for_current_platform(release_json: Dictionary) -> Variant:
	var arch := Engine.get_architecture_name()
	var os := OS.get_name().to_lower()
	var doublet := "%s-%s" % [os, arch]

	for asset: Variant in release_json.assets:
		if doublet in asset.name:
			return asset

	# old method (up to 01214c5 release) until os and arch added to asset names
	for asset: Variant in release_json.assets:
		var asset_content_type := asset.content_type as String
		if asset_content_type == "application/x-msdos-program":
			return asset

	return null


func _update_check_was_long_ago() -> bool:
	var now := Time.get_unix_time_from_system()
	return now >= _last_update_check_time + UPDATE_CHECK_MINIMUM_INTERVAL


func _fetch_latest_release_json() -> Dictionary:
	# var now := Time.get_unix_time_from_system()
	# if _github_ratelimit_remaining == 0 and _github_ratelimit_resettime > now:
	# 	return

	var url := GITHUB_API_ENDPOINT_LATEST_RELEASE % [
		GITHUB_OWNER.uri_encode(),
		GITHUB_REPO.uri_encode(),
	]
	var res := await Utils.fetch(url)
	if res.error != OK:
		return {
			"error": Utils.http_request_error_text(res.error),
		}

	if res.response_error != HTTPRequest.RESULT_SUCCESS:
		return {
			"error": Utils.http_request_result_text(res.response_error),
		}

	if res.response_code != 200:
		return {
			"error": "HTTP %d" % res.response_code,
		}

	var headers = Utils.parse_headers(res.raw_headers, true)
	_update_ratelimits_from_headers(headers)

	var is_json := false
	for hdr: String in headers.keys():
		if hdr == "content-type":
			for v: String in headers[hdr]:
				if "application/json" in v:
					is_json = true
					break

			break

	if not is_json:
		return {
			"error": "Not JSON",
		}

	var body_text := res.body.get_string_from_utf8()
	var body_json: Variant = JSON.parse_string(body_text)

	if body_json == null or body_json is not Dictionary:
		return {
			"error": "Invalid JSON",
		}

	return body_json


func _fetch_asset(
		asset_json: Dictionary,
		output: PackedByteArray,
		progress_callback: Callable,
) -> String:
	var params: Utils.FetchParams
	if progress_callback.is_valid():
		params = Utils.FetchParams.new(
			HTTPClient.METHOD_GET,
			"",
			[],
			progress_callback,
		)

	var res := await Utils.fetch(asset_json.browser_download_url, params)
	if res.error != OK:
		return Utils.http_request_error_text(res.error)

	if res.response_error != HTTPRequest.RESULT_SUCCESS:
		return Utils.http_request_result_text(res.response_error)

	if res.response_code != 200:
		return "HTTP %d" % res.response_code

	output.append_array(res.body)
	return ""

# 	# TODO: make gigbah ci prefix each asset with os and arch
# 	#       for robust selecting asset for end user
# 	if "assets" not in body_json or body_json.assets is not Array:
# 		push_error("github api response doesn't contains assets")
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, "no assets")
# 		game_status = GameStatus.ERROR_UPDATING
# 		break

# 	var windows_asset: Dictionary

# 	var assets := body_json.assets as Array
# 	for asset: Dictionary in assets:
# 		var asset_content_type := asset.content_type as String
# 		if asset_content_type == "application/x-msdos-program":
# 			windows_asset = asset

# 	if not windows_asset:
# 		push_error("latest release doesn't contains asset for windows")
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, "no windows asset")
# 		game_status = GameStatus.ERROR_UPDATING
# 		break

# 	var latest_release_tag := body_json.tag_name as String
# 	var prefs := LauncherPreferences.instance

# 	print("latest release tag is '%s', current '%s'" % [latest_release_tag, prefs.current_release_tag])
# 	actual_version_name = latest_release_tag

# 	if latest_release_tag == prefs.current_release_tag:
# 		game_status = GameStatus.READY
# 		game_runnable = true
# 		primary_action = PrimaryAction.PLAY
# 		break

# 	if not allow_download:
# 		if prefs.current_release_tag.is_empty():
# 			game_status = GameStatus.DOWNLOAD_NEEDED
# 			primary_action = PrimaryAction.DOWNLOAD
# 		else:
# 			game_status = GameStatus.UPDATE_NEEDED
# 			primary_action = PrimaryAction.UPDATE

# 		break

# 	game_status = GameStatus.UPDATING

# 	var asset_bytes := await _download_asset(windows_asset, http)
# 	var asset_store_dir := LauncherPreferences.instance.releases_storage_path
# 	asset_store_dir = asset_store_dir.path_join(latest_release_tag)
# 	var asset_store_fpath := asset_store_dir.path_join(windows_asset.name)

# 	err = DirAccess.make_dir_recursive_absolute(asset_store_dir)
# 	if err != OK:
# 		var err_text := _get_file_error_text(err)
# 		push_error("failed create directory for release: %s" % err_text)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
# 		game_status = GameStatus.ERROR_UPDATING
# 		break

# 	var asset_file := FileAccess.open(asset_store_fpath, FileAccess.WRITE)
# 	if not asset_file:
# 		var err_text := _get_file_error_text(FileAccess.get_open_error())
# 		push_error("failed create asset file on disk: %s" % err_text)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
# 		game_status = GameStatus.ERROR_UPDATING
# 		break

# 	if not asset_file.store_buffer(asset_bytes):
# 		var err_text := _get_file_error_text(asset_file.get_error())
# 		push_error("failed write to asset file on disk: error %d" % err_text)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, err_text)
# 		game_status = GameStatus.ERROR_UPDATING
# 		break

# 	LauncherPreferences.instance.current_release_tag = latest_release_tag
# 	LauncherPreferences.instance.current_release_app_path = asset_store_fpath
# 	LauncherPreferences.instance.save()

# 	game_status = GameStatus.READY
# 	game_runnable = true

# 	# while end
# 	break

# http.queue_free()

# declared here because gdscript captures outter variables by value.
# script variables access is as usual
# var _speed_sample_time: int
# var _speed_sample_prevsize: int

# func _download_asset(asset_json: Dictionary, http: HTTPRequest = null) -> PackedByteArray:
# 	print("downloading asset %s" % asset_json.name)

# 	var asset_body: PackedByteArray

# 	var http_owner := false
# 	if not http:
# 		http = HTTPRequest.new()
# 		http.name = "asset_downloading"
# 		add_child(http)

# 		http_owner = true

# 	_speed_sample_time = Time.get_ticks_msec()
# 	_speed_sample_prevsize = 0

# 	var timer := Timer.new()
# 	timer.wait_time = 0.2
# 	timer.timeout.connect(
# 		func() -> void:
# 			var now := Time.get_ticks_msec()
# 			var time_window := now - _speed_sample_time
# 			var cur_size := http.get_downloaded_bytes()
# 			var size_window := cur_size - _speed_sample_prevsize
# 			var byte_per_sec := int(size_window / (time_window / 1000.0))
# 			var speed_text := "%s/s" % Utils.get_human_readable_byte_size(byte_per_sec)

# 			_speed_sample_time = now
# 			_speed_sample_prevsize = cur_size

# 			var total_size := http.get_body_size()
# 			if total_size < 0:
# 				set_game_status_subtext(GameStatus.UPDATING, speed_text)
# 			else:
# 				@warning_ignore("integer_division")
# 				var pct := 100.0 * cur_size / total_size
# 				set_game_status_subtext(GameStatus.UPDATING, "%.1f%% (%s)" % [pct, speed_text])
# 	)
# 	add_child(timer)

# 	# not loop, only for early breaking branch
# 	while true:
# 		http.request(asset_json.browser_download_url)

# 		timer.start()

# 		var args: Variant = await http.request_completed
# 		var result: int = args[0]
# 		var response_code: int = args[1]
# 		var headers: PackedStringArray = args[2]
# 		var body: PackedByteArray = args[3]

# 		if result != HTTPRequest.RESULT_SUCCESS:
# 			push_error("github asset http response error: %s" % result)
# 			set_game_status_subtext(GameStatus.ERROR_UPDATING, _http_request_result_text(result))
# 			game_status = GameStatus.ERROR_UPDATING
# 			break

# 		if response_code != 200:
# 			push_error("github asset returned http error %d" % response_code)
# 			set_game_status_subtext(GameStatus.ERROR_UPDATING, "HTTP %d" % response_code)
# 			game_status = GameStatus.ERROR_UPDATING

# 		_update_ratelimits_from_headers(headers)

# 		asset_body = body
# 		print("asset downloaded, size=%s" % _get_human_readable_byte_size(asset_body.size()))

# 		# while end
# 		break

# 	timer.paused = true
# 	timer.queue_free()

# 	if http_owner:
# 		http.queue_free()

# 	return asset_body

# 	print("requesting %s" % url)
# 	var err := http.request(url)
# 	if err != OK:
# 		push_error("failed request github api: %s" % _http_request_error_text(err))
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, _http_request_error_text(err))
# 		game_status = GameStatus.ERROR_UPDATING
# 		return

# 	var args: Variant = await http.request_completed
# 	var result: int = args[0]
# 	var response_code: int = args[1]
# 	var headers: PackedStringArray = args[2]
# 	var body: PackedByteArray = args[3]

# 	if result != HTTPRequest.RESULT_SUCCESS:
# 		push_error("github api http response error: %s" % result)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, _http_request_result_text(result))
# 		game_status = GameStatus.ERROR_UPDATING
# 		return

# 	if response_code != 200:
# 		push_error("github api returned http error %d" % response_code)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, "HTTP %d" % response_code)
# 		game_status = GameStatus.ERROR_UPDATING

# 	_update_ratelimits_from_headers(headers)
# 	var content_type: String
# 	for hdr: String in headers:
# 		var kv := hdr.split(":", true, 1)
# 		match kv[0].to_lower():
# 			"content-type":
# 				content_type = kv[1].strip_edges()

# 	if "application/json" not in content_type:
# 		push_error("github api respond with non json (content type is '%s')" % content_type)
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, "not json")
# 		game_status = GameStatus.ERROR_UPDATING
# 		return

# 	var body_text := body.get_string_from_utf8()
# 	var body_json: Variant = JSON.parse_string(body_text)

# 	if body_json == null or body_json is not Dictionary:
# 		push_error("github api respond with invalid json")
# 		set_game_status_subtext(GameStatus.ERROR_UPDATING, "invalid json")
# 		game_status = GameStatus.ERROR_UPDATING
# 		return


func _update_ratelimits_from_headers(headers: Dictionary[String, PackedStringArray]) -> void:
	if "x-ratelimit-remaining" in headers:
		_github_ratelimit_remaining = headers["x-ratelimit-remaining"][0].to_int()
		print("rate limit remaining: %d" % _github_ratelimit_remaining)

	if "x-ratelimit-reset" in headers:
		_github_ratelimit_resettime = headers["x-ratelimit-reset"][0].to_int() as float
		print("rate limit reset time: %.0f" % _github_ratelimit_resettime)


enum LauncherState {
	START,
	INSTALLATION_CHECK,
	NOT_INSTALLED,
	DOWNLOAD,
	UPDATE_CHECK,
	UPDATE_CHECK_ERROR,
	OUTDATED,
	UPDATING,
	UPDATED,
	UPDATE_ERROR,
	READY_TO_PLAY,
	PLAYING,
	END_PLAYING,
}
