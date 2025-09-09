extends Control

@onready var cctv_monitor_scene: PackedScene = preload("res://scenes/CCTVMonitor.tscn")
@onready var startup_link_scene: PackedScene = preload("res://scenes/StartupLink.tscn")
@onready var drone_scene: PackedScene = preload("res://scenes/Drone.tscn")
@onready var naming_overlay_scene: PackedScene = preload("res://ui/NamingOverlay.tscn")
@onready var station_scene: PackedScene = preload("res://levels/TestStation.tscn")

var _drone: Node = null
var _monitor: Node
var _timer_label: Label
var _session_start_time_s: float = 0.0
var _feed_title: Label
var _status_label: Label
var _status_shown: bool = false
@export var debug_mode: bool = true
@export var enable_debug_logging: bool = false
var _toast: Label
var _naming_target: Node = null
var _zoomed: bool = false
var _station: Node = null

func _is_drone(n: Node) -> bool:
	return n != null and n.has_method("set_possessed") and n.has_method("apply_look")

func _get_memory_ratio(d: Node) -> float:
	if not _is_drone(d):
		return 0.0
	var mem: DroneMemory = d.memory as DroneMemory
	if mem:
		return mem.get_pressure_ratio()
	return 0.0

func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	_ensure_fullscreen()
	_ensure_input_actions()
	if not debug_mode:
		await _show_startup_then_console()
	add_to_group("OperatorConsole")
	_build_console_ui()
	_init_station_and_drone()
	_apply_feed_to_monitor()
	_check_unnamed_startup()
	_session_start_time_s = Time.get_unix_time_from_system()

func _process(_delta: float) -> void:
	if is_instance_valid(_timer_label):
		var elapsed := int(Time.get_unix_time_from_system() - _session_start_time_s)
		var mins := int(elapsed / 60.0)
		var secs := elapsed % 60
		_timer_label.text = "SESSION %02d:%02d" % [mins, secs]
	# Update live XYZ
	var pos_label := get_node_or_null("ConsoleRoot/TopBar/PosLabel") as Label
	if pos_label and _drone and _drone is Node3D:
		var p := (_drone as Node3D).global_transform.origin
		pos_label.text = "XYZ: %.2f, %.2f, %.2f" % [p.x, p.y, p.z]

func _ensure_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func _ensure_input_actions() -> void:
	var to_add: Array = [
		{"name": "move_forward", "keys": [KEY_W, KEY_UP]},
		{"name": "move_back", "keys": [KEY_S, KEY_DOWN]},
		{"name": "move_left", "keys": [KEY_A, KEY_LEFT]},
		{"name": "move_right", "keys": [KEY_D, KEY_RIGHT]},
		{"name": "zoom_feed", "keys": [KEY_R]},
		{"name": "rotate_left", "keys": [KEY_E]},
		{"name": "rotate_right", "keys": [KEY_Q]},
		{"name": "zoom_in", "keys": [KEY_EQUAL]},
		{"name": "zoom_out", "keys": [KEY_MINUS]},
		{"name": "pitch_up", "keys": [KEY_I]},
		{"name": "pitch_down", "keys": [KEY_K]},
		{"name": "possess_toggle", "keys": [KEY_TAB]},
		{"name": "escape_release", "keys": [KEY_ESCAPE]},
		{"name": "ui_page_up", "keys": [KEY_PAGEUP]},
		{"name": "ui_page_down", "keys": [KEY_PAGEDOWN]}
	]
	for item in to_add:
		var action := String(item["name"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if item.has("keys"):
			for key in item["keys"]:
				# Add both keycode and physical_keycode bindings for reliability across layouts
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				if not _has_event(action, ev):
					InputMap.action_add_event(action, ev)
				var ev2 := InputEventKey.new()
				ev2.keycode = key
				if not _has_event(action, ev2):
					InputMap.action_add_event(action, ev2)

	# Enforce swapped bindings for rotate actions
	_set_action_to_single_key("rotate_left", KEY_E)
	_set_action_to_single_key("rotate_right", KEY_Q)

func _has_event(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e.as_text() == ev.as_text():
			return true
	return false

func _set_action_to_single_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _show_startup_then_console() -> void:
	var startup := startup_link_scene.instantiate()
	add_child(startup)
	if startup.has_signal("finished"):
		await startup.finished
	else:
		await get_tree().create_timer(3.0).timeout
	startup.queue_free()

func _build_console_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "ConsoleRoot"
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.custom_minimum_size = Vector2(0, 32)
	root.add_child(top)

	_timer_label = Label.new()
	_timer_label.text = "SESSION 00:00"
	top.add_child(_timer_label)

	_feed_title = Label.new()
	_feed_title.text = "DRONE: —"
	_feed_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_feed_title)

	_status_label = Label.new()
	_status_label.text = "DRONE ONLINE"
	# Live XYZ readout
	var pos := Label.new()
	pos.name = "PosLabel"
	top.add_child(pos)
	top.add_child(_status_label)

	var main := HBoxContainer.new()
	main.name = "MainArea"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var side := VBoxContainer.new()
	side.name = "LeftPanel"
	side.custom_minimum_size = Vector2(280, 0)
	side.size_flags_horizontal = Control.SIZE_FILL
	main.add_child(side)

	var side_title := Label.new()
	side_title.text = "DRONE"
	side.add_child(side_title)

	_monitor = cctv_monitor_scene.instantiate()
	_monitor.name = "CCTVMonitor"
	if _monitor is Control:
		(_monitor as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(_monitor as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Propagate debug flag to monitor so its on-screen label obeys our setting
	if _monitor:
		_monitor.set("enable_debug_logging", enable_debug_logging)
	main.add_child(_monitor)

	# Single-drone: no feed toggle or spawn controls

	_toast = Label.new()
	_toast.name = "Toast"
	_toast.text = ""
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_bottom = -12
	add_child(_toast)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "[Tab] toggle control  |  +/-: FOV  |  Q/E: yaw  |  I/K: pitch  |  R: monitor zoom"
	hint.modulate = Color(0.85, 0.85, 0.9, 0.9)
	hint.anchor_left = 0.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 8
	hint.offset_bottom = -36
	add_child(hint)

	# Single-drone: no pool required

	# Naming overlay disabled: auto-assign codename at startup
	# _naming_overlay = naming_overlay_scene.instantiate()
	# add_child(_naming_overlay)
	# _naming_overlay.connect("name_confirmed", Callable(self, "_on_overlay_name_confirmed"))
	# _naming_overlay.connect("name_canceled", Callable(self, "_on_overlay_name_canceled"))

	# Registry removed in single-drone scope

func _init_station_and_drone() -> void:
	_drone = null
	if station_scene:
		if enable_debug_logging:
			print("[Console] Instancing station")
		_station = station_scene.instantiate()
		_station.name = "SpaceStationInstance"
		add_child(_station)
		await get_tree().process_frame
		if enable_debug_logging:
			print("[Console] Station ready: ", _station)
		var d := _station.get_node_or_null("Drone")
		if d == null and is_instance_valid(_station.get_node_or_null("DroneSpawn")):
			if enable_debug_logging:
				print("[Console] Spawning drone at DroneSpawn")
			var spawn := _station.get_node("DroneSpawn") as Marker3D
			var new_drone := drone_scene.instantiate()
			new_drone.name = "Drone"
			_station.add_child(new_drone)
			new_drone.add_to_group("PlayerDrone")
			new_drone.global_transform = spawn.global_transform
			d = new_drone
		if d != null:
			_drone = d
			if d.has_signal("memory_pressure_changed"):
				d.memory_pressure_changed.connect(_on_drone_pressure_changed.bind(d))
			# Auto-name and ensure camera is current
			if _is_drone(_drone) and not _drone.is_named:
				_drone.codename = _generate_callsign()
				_drone.is_named = true
			var cam := _drone.get_node_or_null("CameraPivot/Camera3D") as Camera3D
			if cam:
				cam.current = true
			_update_feed_title()
			# Bind feed now that drone exists
			_apply_feed_to_monitor()

func _spawn_drones(_count: int) -> void:
	# Single-drone: spawning disabled
	pass

func _populate_drone_list_ui() -> void:
	# Single-drone: list UI removed
	pass

func _update_active_highlight() -> void:
	# Single-drone: no highlight
	pass

func _apply_feed_to_monitor() -> void:
	if _drone == null:
		return
	# Resolve the actual camera and pass it directly for robustness
	var cam := _drone.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if _monitor and _monitor.has_method("set_feed"):
		if cam:
			_monitor.set_feed(cam)
		else:
			_monitor.set_feed(_drone)
	var ratio: float = _get_memory_ratio(_drone)
	if _monitor and _monitor.has_method("set_memory_pressure"):
		_monitor.set_memory_pressure(ratio)
	_update_status()
	_update_feed_title()
	# Diagnostics: confirm camera binding
	var cam_diag := cam
	if cam_diag:
		if enable_debug_logging:
			print("[ConsoleDiag] Drone camera path:", cam_diag.get_path())
	if _monitor and _monitor.has_node("SubViewport"):
		var vp := _monitor.get_node("SubViewport") as SubViewport
		var tex := vp.get_texture()
		if enable_debug_logging:
			print("[ConsoleDiag] VP size:", vp.size, " cam_current:", (cam_diag and cam_diag.current), " tex:", tex != null)

	# Auto-possess and force camera current on startup (keyboard-only; no mouse capture)
	if _is_drone(_drone):
		_drone.set_possessed(true)
		if cam:
			cam.current = true

func _on_toggle_feed_pressed() -> void:
	# Single-drone: no alternate feeds
	pass

func _cycle_possession(_delta_index: int) -> void:
	# Single-drone: possession cycling removed
	pass

func _release_possession() -> void:
	if _is_drone(_drone):
		_drone.set_possessed(false)
	_update_status()

func _toggle_possession() -> void:
	if not _is_drone(_drone):
		return
	if _drone.is_possessed():
		_release_possession()
	else:
		_drone.set_possessed(true)
		var cam := _drone.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if cam:
			cam.current = true

func _toggle_zoom() -> void:
	_zoomed = not _zoomed
	if is_instance_valid(_monitor):
		_monitor.stretch_shrink = 2 if _zoomed else 1

func _on_drone_pressure_changed(ratio: float, _unused_drone: Node) -> void:
	if _monitor and _monitor.has_method("set_memory_pressure"):
		_monitor.set_memory_pressure(ratio)
	_update_status()

func _update_drone_list_bars() -> void:
	# Single-drone: no list bars
	pass

func _adjust_current_drone_memory(delta_mb: float) -> void:
	if _drone == null:
		return
	if _is_drone(_drone):
		var mem: DroneMemory = _drone.memory as DroneMemory
		if mem:
			if delta_mb > 0.0:
				mem.claim(delta_mb)
			else:
				mem.release(-delta_mb)

func _input(_event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	# Diagnostics: log movement/rotation key events
	if event is InputEventKey and event.pressed:
		if enable_debug_logging:
			if event.physical_keycode in [KEY_W, KEY_UP]:
				print("[ConsoleDiag] move_forward pressed")
			if event.physical_keycode in [KEY_S, KEY_DOWN]:
				print("[ConsoleDiag] move_back pressed")
			if event.physical_keycode in [KEY_A, KEY_LEFT]:
				print("[ConsoleDiag] move_left pressed")
			if event.physical_keycode in [KEY_D, KEY_RIGHT]:
				print("[ConsoleDiag] move_right pressed")
			if event.physical_keycode == KEY_Q:
				print("[ConsoleDiag] rotate_right pressed")
			if event.physical_keycode == KEY_E:
				print("[ConsoleDiag] rotate_left pressed")
	if event.is_action_pressed("possess_toggle"):
		if enable_debug_logging:
			print("[Console] possess_toggle")
		_toggle_possession()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("escape_release"):
		_release_possession()
		return
	if event.is_action_pressed("zoom_feed"):
		_toggle_zoom()
		return
	if event.is_action_pressed("zoom_in") and _is_drone(_drone):
		_drone.zoom_in()
		return
	if event.is_action_pressed("zoom_out") and _is_drone(_drone):
		_drone.zoom_out()
		return
	if event.is_action_pressed("ui_page_up"):
		_adjust_current_drone_memory(4.0)
		_apply_feed_to_monitor()
		return
	if event.is_action_pressed("ui_page_down"):
		_adjust_current_drone_memory(-4.0)
		_apply_feed_to_monitor()
		return

func _update_feed_title() -> void:
	var code: String = "—"
	if _is_drone(_drone) and _drone.is_named:
		code = String(_drone.codename)
	_feed_title.text = "DRONE: %s" % code

func _update_status() -> void:
	if _status_label == null:
		return
	if not _status_shown:
		_status_shown = true
		_status_label.visible = true
		await get_tree().create_timer(1.2).timeout
		_status_label.visible = false

func _show_toast(msg: String) -> void:
	if _toast == null:
		return
	_toast.text = msg
	_toast.visible = true
	await get_tree().create_timer(1.6).timeout
	if _toast.text == msg:
		_toast.visible = false

func _on_spawn_test_drone_pressed() -> void:
	# Single-drone scope: spawning additional drones disabled
	_show_toast("Single-drone mode: spawn disabled")

func _on_drone_registered(_unused_drone: Node) -> void:
	# Registry removed; keep stub for safety
	pass

func _on_drone_named(_named: Node, codename: String) -> void:
	_update_feed_title()
	_update_status()
	_show_toast("Unit confirmed: %s" % codename)

func _open_naming_for(drone: Node) -> void:
	_naming_target = drone
	# _naming_overlay.call("open_for", drone) # Naming overlay disabled

func _on_overlay_name_confirmed(new_name: String) -> void:
	if _naming_target == null:
		return
	if _is_drone(_naming_target):
		_naming_target.codename = new_name
		_naming_target.is_named = true
	_populate_drone_list_ui()
	_update_feed_title()
	if _naming_target == _drone:
		_drone.set_possessed(true)
		_update_status()
	_naming_target = null

func _on_overlay_name_canceled() -> void:
	_show_toast("Name required to proceed")

func _check_unnamed_startup() -> void:
	if _is_drone(_drone) and not _drone.is_named:
		_open_naming_for(_drone)

func _generate_callsign() -> String:
	var bank: Array[String] = [
		"ARGUS", "NOVA", "VIGIL", "SABLE", "ONYX", "LYNX", "KITE",
		"IRIS", "KRAIT", "DELTA", "ECHO", "TANGO"
	]
	var index: int = int(randi()) % bank.size()
	var letters: String = bank[index]
	var number: int = int(randi() % 90) + 10
	return "%s %02d" % [letters, number]
