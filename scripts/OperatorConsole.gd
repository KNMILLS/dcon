extends Control

@onready var cctv_monitor_scene: PackedScene = preload("res://scenes/CCTVMonitor.tscn")
@onready var startup_link_scene: PackedScene = preload("res://scenes/StartupLink.tscn")
@onready var drone_scene: PackedScene = preload("res://scenes/Drone.tscn")
@onready var naming_overlay_scene: PackedScene = preload("res://ui/NamingOverlay.tscn")

var _drones: Array[Node] = []
var _drone_item_nodes: Array[Control] = []
var _current_feed_index: int = 0
var _possessed_index: int = -1
var _monitor: Node
var _timer_label: Label
var _session_start_time_s: float = 0.0
var _feed_title: Label
var _toast: Label
var _naming_overlay: Control
var _naming_target: Node = null
var _zoomed: bool = false

func _ready() -> void:
	_ensure_fullscreen()
	_ensure_input_actions()
	await _show_startup_then_console()
	_build_console_ui()
	_spawn_drones(3)
	_populate_drone_list_ui()
	_apply_feed_to_monitor()
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
		{"name": "toggle_feed", "keys": [KEY_TAB]},
		{"name": "possess_next_drone", "keys": [KEY_P]},
		{"name": "possess_prev_drone", "keys": [KEY_O]},
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
	side_title.text = "DRONES"
	side.add_child(side_title)

	var list := VBoxContainer.new()
	list.name = "DroneList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(list)

	_monitor = cctv_monitor_scene.instantiate()
	_monitor.name = "CCTVMonitor"
	main.add_child(_monitor)

	var switcher := Button.new()
	switcher.text = "Toggle Feed (Tab)"
	switcher.pressed.connect(_on_toggle_feed_pressed)
	side.add_child(switcher)

	var spawn := Button.new()
	spawn.text = "Spawn Test Drone"
	spawn.pressed.connect(_on_spawn_test_drone_pressed)
	side.add_child(spawn)

	_toast = Label.new()
	_toast.name = "Toast"
	_toast.text = ""
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_bottom = -12
	add_child(_toast)

	var pool := Node.new()
	pool.name = "DronePool"
	add_child(pool)

	_naming_overlay = naming_overlay_scene.instantiate()
	add_child(_naming_overlay)
	_naming_overlay.connect("name_confirmed", Callable(self, "_on_overlay_name_confirmed"))
	_naming_overlay.connect("name_canceled", Callable(self, "_on_overlay_name_canceled"))

	var reg := get_node_or_null("/root/DroneRegistry")
	if reg:
		reg.connect("drone_registered", Callable(self, "_on_drone_registered"))
		reg.connect("drone_named", Callable(self, "_on_drone_named"))

func _spawn_drones(count: int) -> void:
	_drones.clear()
	for i in count:
		var d := drone_scene.instantiate()
		d.name = "DRN-%d" % (i + 1)
		_drones.append(d)
		if d.has_signal("memory_pressure_changed"):
			d.memory_pressure_changed.connect(_on_drone_pressure_changed.bind(d))

func _populate_drone_list_ui() -> void:
	_drone_item_nodes.clear()
	var list := get_node("ConsoleRoot/MainArea/LeftPanel/DroneList") as VBoxContainer
	for c in list.get_children():
		c.queue_free()
	for i in _drones.size():
		var item := HBoxContainer.new()
		item.name = "DroneItem%d" % i
		var label := Label.new()
		var d := _drones[i]
		var named: bool = d.has("is_named") and d.is_named
		var code: String = _drones[i].name
		if d.has("codename"):
			code = String(d.codename)
		label.text = code if named else "(UNNAMED)"
		item.add_child(label)
		var mem_bar := ProgressBar.new()
		mem_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mem_bar.value = 0.0
		mem_bar.max_value = 100.0
		item.add_child(mem_bar)
		list.add_child(item)
		_drone_item_nodes.append(item)
	_update_active_highlight()

func _update_active_highlight() -> void:
	for i in _drone_item_nodes.size():
		var is_active := (i == _current_feed_index)
		_drone_item_nodes[i].self_modulate = Color(1, 1, 1, 1) if is_active else Color(0.7, 0.7, 0.7, 1)
	_update_drone_list_bars()

func _apply_feed_to_monitor() -> void:
	if _drones.is_empty():
		return
	var source := _drones[_current_feed_index]
	if _monitor and _monitor.has_method("set_feed"):
		_monitor.set_feed(source)
	var cam := source.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		cam = source.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if cam:
		cam.current = true
	# Push current drone memory pressure to shader
	var ratio: float = 0.0
	if source.has("memory"):
		var mem: DroneMemory = source.memory as DroneMemory
		if mem:
			ratio = mem.get_pressure_ratio()
	if _monitor and _monitor.has_method("set_memory_pressure"):
		_monitor.set_memory_pressure(ratio)
	_update_feed_title()
	_update_active_highlight()

func _on_toggle_feed_pressed() -> void:
	if _drones.is_empty():
		return
	_current_feed_index = (_current_feed_index + 1) % _drones.size()
	_apply_feed_to_monitor()
	_update_active_highlight()

func _cycle_possession(delta_index: int) -> void:
	if _drones.is_empty():
		return
	if _possessed_index >= 0 and _possessed_index < _drones.size():
		var prev := _drones[_possessed_index]
		if prev.has_method("set_possessed"):
			prev.set_possessed(false)
	_possessed_index = (_possessed_index + delta_index + _drones.size()) % _drones.size()
	_current_feed_index = _possessed_index
	_apply_feed_to_monitor()
	_update_active_highlight()
	var cur := _drones[_possessed_index]
	if cur.has_method("set_possessed"):
		cur.set_possessed(true)

func _release_possession() -> void:
	if _possessed_index >= 0 and _possessed_index < _drones.size():
		var d := _drones[_possessed_index]
		if d.has_method("set_possessed"):
			d.set_possessed(false)
	_possessed_index = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _toggle_zoom() -> void:
	_zoomed = not _zoomed
	if is_instance_valid(_monitor):
		_monitor.stretch_shrink = 2 if _zoomed else 1

func _on_drone_pressure_changed(ratio: float, drone: Node) -> void:
	_update_drone_list_bars()
	if _drones.size() > 0 and drone == _drones[_current_feed_index]:
		if _monitor and _monitor.has_method("set_memory_pressure"):
			_monitor.set_memory_pressure(ratio)

func _update_drone_list_bars() -> void:
	var list := get_node("ConsoleRoot/MainArea/LeftPanel/DroneList") as VBoxContainer
	for i in _drones.size():
		var item := list.get_node("DroneItem%d" % i) as HBoxContainer
		if item and item.get_child_count() >= 2:
			var mem_bar := item.get_child(1) as ProgressBar
			var ratio: float = 0.0
			var d := _drones[i]
			if d.has("memory"):
				var mem: DroneMemory = d.memory as DroneMemory
				if mem:
					ratio = mem.get_pressure_ratio()
			mem_bar.value = ratio * 100.0

func _adjust_current_drone_memory(delta_mb: float) -> void:
	if _drones.is_empty():
		return
	var d := _drones[_current_feed_index]
	if d.has("memory"):
		var mem: DroneMemory = d.memory as DroneMemory
		if mem:
			if delta_mb > 0.0:
				mem.claim(delta_mb)
			else:
				mem.release(-delta_mb)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_feed"):
		_on_toggle_feed_pressed()
	elif event.is_action_pressed("possess_next_drone"):
		_on_toggle_feed_pressed()
	elif event.is_action_pressed("possess_prev_drone"):
		_cycle_possession(-1)
	elif event.is_action_pressed("close"):
		_release_possession()
	elif event.is_action_pressed("zoom_feed"):
		_toggle_zoom()
	elif event is InputEventMouseMotion:
		if _possessed_index >= 0 and _possessed_index < _drones.size():
			var d := _drones[_possessed_index]
			if d.has_method("apply_look"):
				d.apply_look(event.relative)

func _update_feed_title() -> void:
	if _drones.is_empty():
		_feed_title.text = "DRONE: —"
		return
	var d := _drones[_current_feed_index]
	var code: String = d.name
	if d.has("codename"):
		code = String(d.codename)
	if d.has("is_named") and not d.is_named:
		code = "—"
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
	var pool := get_node_or_null("DronePool")
	if pool == null:
		pool = self
	var d := drone_scene.instantiate()
	d.name = "DRN-%d" % (_drones.size() + 1)
	pool.add_child(d)
	_drones.append(d)
	_populate_drone_list_ui()
	_apply_feed_to_monitor()

func _on_drone_registered(drone: Node) -> void:
	if not (drone.has("is_named") and drone.has("codename")):
		return
	if not drone.is_named:
		_open_naming_for(drone)
	_populate_drone_list_ui()

func _on_drone_named(_drone: Node, codename: String) -> void:
	_populate_drone_list_ui()
	_update_feed_title()
	_show_toast("Unit confirmed: %s" % codename)

func _open_naming_for(drone: Node) -> void:
	_naming_target = drone
	_naming_overlay.call("open_for", drone)

func _on_overlay_name_confirmed(name: String) -> void:
	if _naming_target == null:
		return
	if _naming_target.has("codename"):
		_naming_target.codename = name
	if _naming_target.has("is_named"):
		_naming_target.is_named = true
	var reg := get_node_or_null("/root/DroneRegistry")
	if reg:
		reg.call("mark_named", _naming_target)
	_populate_drone_list_ui()
	_update_feed_title()
	_naming_target = null

func _on_overlay_name_canceled() -> void:
	_show_toast("Name required to proceed")

func _check_unnamed_startup() -> void:
	for d in _drones:
		if d.has("is_named") and not d.is_named:
			_open_naming_for(d)
			break
