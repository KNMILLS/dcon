extends Control

@onready var cctv_monitor_scene: PackedScene = preload("res://scenes/CCTVMonitor.tscn")
@onready var startup_link_scene: PackedScene = preload("res://scenes/StartupLink.tscn")
@onready var drone_scene: PackedScene = preload("res://scenes/Drone.tscn")
@onready var naming_overlay_scene: PackedScene = preload("res://ui/NamingOverlay.tscn")
@onready var station_scene: PackedScene = preload("res://scenes/SpaceStation.tscn")

var _drone: Node = null
var _monitor: Node
var _timer_label: Label
var _session_start_time_s: float = 0.0
var _feed_title: Label
var _toast: Label
var _naming_overlay: Control
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
	_ensure_fullscreen()
	_ensure_input_actions()
	await _show_startup_then_console()
	_build_console_ui()
	_init_station_and_drone()
	_apply_feed_to_monitor()
	_check_unnamed_startup()
	_session_start_time_s = Time.get_unix_time_from_system()

func _process(_delta: float) -> void:
	if is_instance_valid(_timer_label):
		var elapsed := int(Time.get_unix_time_from_system() - _session_start_time_s)
		var mins := elapsed / 60
		var secs := elapsed % 60
		_timer_label.text = "SESSION %02d:%02d" % [mins, secs]

func _ensure_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _ensure_input_actions() -> void:
	var to_add: Array = [
		{"name": "move_forward", "keys": [KEY_W]},
		{"name": "move_back", "keys": [KEY_S]},
		{"name": "move_left", "keys": [KEY_A]},
		{"name": "move_right", "keys": [KEY_D]},
		{"name": "mouse_look", "mouse": true},
		{"name": "zoom_feed", "keys": [KEY_Q]},
		{"name": "close", "keys": [KEY_ESCAPE]},
		{"name": "ui_page_up", "keys": [KEY_PAGEUP]},
		{"name": "ui_page_down", "keys": [KEY_PAGEDOWN]}
	]
	for item in to_add:
		var action := String(item["name"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if item.has("keys"):
			for key in item["keys"]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				if not _has_event(action, ev):
					InputMap.action_add_event(action, ev)
		if item.has("mouse") and item["mouse"]:
			var mev := InputEventMouseMotion.new()
			if not _has_event(action, mev):
				InputMap.action_add_event(action, mev)

func _has_event(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e.as_text() == ev.as_text():
			return true
	return false

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

	# Single-drone: no pool required

	_naming_overlay = naming_overlay_scene.instantiate()
	add_child(_naming_overlay)
	_naming_overlay.connect("name_confirmed", Callable(self, "_on_overlay_name_confirmed"))
	_naming_overlay.connect("name_canceled", Callable(self, "_on_overlay_name_canceled"))

	# Registry removed in single-drone scope

func _init_station_and_drone() -> void:
	_drone = null
	if station_scene:
		_station = station_scene.instantiate()
		_station.name = "SpaceStationInstance"
		add_child(_station)
		var d := _station.get_node_or_null("Drone")
		if d != null:
			_drone = d
			if d.has_signal("memory_pressure_changed"):
				d.memory_pressure_changed.connect(_on_drone_pressure_changed.bind(d))

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
	if _monitor and _monitor.has_method("set_feed"):
		_monitor.set_feed(_drone)
	var ratio: float = _get_memory_ratio(_drone)
	if _monitor and _monitor.has_method("set_memory_pressure"):
		_monitor.set_memory_pressure(ratio)
	_update_feed_title()

func _on_toggle_feed_pressed() -> void:
	# Single-drone: no alternate feeds
	pass

func _cycle_possession(_delta_index: int) -> void:
	# Single-drone: possession cycling removed
	pass

func _release_possession() -> void:
	if _is_drone(_drone):
		_drone.set_possessed(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _toggle_zoom() -> void:
	_zoomed = not _zoomed
	if is_instance_valid(_monitor):
		_monitor.stretch_shrink = 2 if _zoomed else 1

func _on_drone_pressure_changed(ratio: float, _unused_drone: Node) -> void:
	if _monitor and _monitor.has_method("set_memory_pressure"):
		_monitor.set_memory_pressure(ratio)

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("close"):
		_release_possession()
	elif event.is_action_pressed("zoom_feed"):
		_toggle_zoom()
	elif event.is_action_pressed("ui_page_up"):
		_adjust_current_drone_memory(4.0)
		_apply_feed_to_monitor()
	elif event.is_action_pressed("ui_page_down"):
		_adjust_current_drone_memory(-4.0)
		_apply_feed_to_monitor()
	elif event is InputEventMouseMotion:
		if _is_drone(_drone):
			_drone.apply_look(event.relative)

func _update_feed_title() -> void:
	var code: String = "—"
	if _is_drone(_drone) and _drone.is_named:
		code = String(_drone.codename)
	_feed_title.text = "DRONE: %s" % code

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
	_show_toast("Unit confirmed: %s" % codename)

func _open_naming_for(drone: Node) -> void:
	_naming_target = drone
	_naming_overlay.call("open_for", drone)

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
	_naming_target = null

func _on_overlay_name_canceled() -> void:
	_show_toast("Name required to proceed")

func _check_unnamed_startup() -> void:
	if _is_drone(_drone) and not _drone.is_named:
		_open_naming_for(_drone)
