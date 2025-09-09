extends Node

const TestReport = preload("res://tests/utils/test_report.gd")
const TestAssert = preload("res://tests/utils/test_assert.gd")

@onready var R: TestReport = TestReport.new()
@onready var A: Node = TestAssert.new()

func _ready() -> void:
	add_child(R)
	add_child(A)
	await _run_foundation()
	await _run_visor()
	R.write_json()
	var all_ok := true
	for r in R.results:
		if r.find("FAIL") != -1:
			all_ok = false
			break
	print("[TESTSUITE][SUMMARY]", ", ".join(R.results))
	await get_tree().process_frame
	get_tree().quit()

# Milestone 0
func _run_foundation() -> void:
	await _test_drone_spawn()
	await _test_movement()
	await _test_camera_binding()
	await _test_subviewport_config()

func _test_drone_spawn() -> void:
	var name := "M0.DroneSpawn"
	var st := await _instance_station()
	if st == null:
		R.mark_fail(name, "No station")
		return
	var d := st.get_node_or_null("Drone") as CharacterBody3D
	if d == null:
		R.mark_fail(name, "Drone not found")
		st.queue_free()
		return
	var from := d.global_transform.origin
	var hit := d.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0))
	if hit.size() == 0:
		R.mark_fail(name, "No collider below drone at "+str(from))
	else:
		R.mark_pass(name)
	st.queue_free()

func _test_movement() -> void:
	var name := "M0.Movement"
	var st := await _instance_station()
	var d := st.get_node_or_null("Drone") as CharacterBody3D
	if d == null:
		R.mark_fail(name, "Drone not found")
		st.queue_free()
		return
	if d.has_method("set_possessed"):
		d.set_possessed(true)
	await get_tree().process_frame
	var start := d.global_transform.origin
	var t := 0.0
	while t < 0.5:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().process_frame
	var moved := d.global_transform.origin.distance_to(start) > 0.2
	if not moved:
		R.mark_fail(name, "No displacement")
	else:
		R.mark_pass(name)
	st.queue_free()

func _test_camera_binding() -> void:
	var name := "M0.CameraBinding"
	var cscene := load("res://scenes/OperatorConsole.tscn") as PackedScene
	var cons := cscene.instantiate()
	add_child(cons)
	await get_tree().process_frame
	var st := cons.get_node_or_null("SpaceStationInstance")
	var d := st.get_node_or_null("Drone") as CharacterBody3D if st else null
	var cam := d.get_node_or_null("CameraPivot/Camera3D") as Camera3D if d else null
	var mon := cons.find_child("CCTVMonitor", true, false)
	var vp := mon.get_node_or_null("SubViewport") as SubViewport if mon else null
	var vcam := vp.get_node_or_null("ViewportCamera") as Camera3D if vp else null
	if not (d and cam and mon and vp and vcam):
		R.mark_fail(name, "Missing nodes")
		cons.queue_free()
		return
	if cons.has_method("_apply_feed_to_monitor"):
		cons._apply_feed_to_monitor()
	await get_tree().process_frame
	await get_tree().process_frame
	var follow := cam.global_transform.is_equal_approx(vcam.global_transform)
	var vp_ok := vp.size.x > 0 and vp.size.y > 0 and vp.get_texture() != null
	if follow and vp_ok:
		R.mark_pass(name)
	else:
		R.mark_fail(name, "follow=%s vp_ok=%s" % [str(follow), str(vp_ok)])
	cons.queue_free()

func _test_subviewport_config() -> void:
	var name := "M0.SubViewportCfg"
	var cscene := load("res://scenes/OperatorConsole.tscn") as PackedScene
	var cons := cscene.instantiate()
	add_child(cons)
	await get_tree().process_frame
	var mon := cons.find_child("CCTVMonitor", true, false)
	var vp := mon.get_node_or_null("SubViewport") as SubViewport if mon else null
	if not (vp and mon):
		R.mark_fail(name, "Missing monitor or viewport")
		cons.queue_free()
		return
	var size_ok := vp.size == Vector2i(640, 360) or (vp.size.x >= 320 and vp.size.y >= 180)
	var tex_ok := vp.get_texture() != null
	if size_ok and tex_ok:
		R.mark_pass(name)
	else:
		R.mark_fail(name, "size=%s tex=%s" % [str(vp.size), str(tex_ok)])
	cons.queue_free()

# Milestone 1
func _run_visor() -> void:
	await _test_visor_modes()
	await _test_glitch_intensity()

func _test_visor_modes() -> void:
	var name := "M1.VisorModes"
	var cscene := load("res://scenes/OperatorConsole.tscn") as PackedScene
	var cons := cscene.instantiate()
	add_child(cons)
	await get_tree().process_frame
	var mon := cons.find_child("CCTVMonitor", true, false)
	if mon == null:
		R.mark_fail(name, "Monitor not found")
		cons.queue_free()
		return
	var ok := false
	if mon.has_method("set_visor_mode"):
		mon.set_visor_mode(1)
		await get_tree().process_frame
		mon.set_visor_mode(2)
		await get_tree().process_frame
		mon.set_visor_mode(0)
		await get_tree().process_frame
		ok = true
	else:
		for action in ["visor_edge","visor_thermal","visor_none"]:
			if not InputMap.has_action(action):
				InputMap.add_action(action)
		Input.action_press("visor_edge")
		await get_tree().process_frame
		Input.action_release("visor_edge")
		Input.action_press("visor_thermal")
		await get_tree().process_frame
		Input.action_release("visor_thermal")
		Input.action_press("visor_none")
		await get_tree().process_frame
		Input.action_release("visor_none")
		ok = true
	var mat: ShaderMaterial = null
	if mon is CanvasItem:
		var base_mat := (mon as CanvasItem).material
		if base_mat is ShaderMaterial:
			mat = base_mat
	if mat:
		mat.set_shader_parameter("mode", 1)
		await get_tree().process_frame
		ok = ok and int(mat.get_shader_parameter("mode")) == 1
	if ok:
		R.mark_pass(name)
	else:
		R.mark_fail(name, "Mode switching not wired")
	cons.queue_free()

func _test_glitch_intensity() -> void:
	var name := "M1.GlitchIntensity"
	var cscene := load("res://scenes/OperatorConsole.tscn") as PackedScene
	var cons := cscene.instantiate()
	add_child(cons)
	await get_tree().process_frame
	var st := cons.get_node_or_null("SpaceStationInstance")
	var d := st.get_node_or_null("Drone") as Node if st else null
	var mon := cons.find_child("CCTVMonitor", true, false)
	if not (d and mon):
		R.mark_fail(name, "Missing drone/monitor")
		cons.queue_free()
		return
	var mat2: ShaderMaterial = null
	if mon is CanvasItem:
		var base_mat2 := (mon as CanvasItem).material
		if base_mat2 is ShaderMaterial:
			mat2 = base_mat2
	if not mat2:
		R.mark_fail(name, "No post shader")
		cons.queue_free()
		return
	var mem: DroneMemory = (d.get("memory") as DroneMemory) if d else null
	if mem == null:
		R.mark_fail(name, "No DroneMemory")
		cons.queue_free()
		return
	mem.set_used_mb(mem.capacity_mb * 0.8)
	await get_tree().process_frame
	var hi := float(mat2.get_shader_parameter("glitch_intensity"))
	mem.set_used_mb(mem.capacity_mb * 0.1)
	await get_tree().process_frame
	var lo := float(mat2.get_shader_parameter("glitch_intensity"))
	if hi > lo:
		R.mark_pass(name)
	else:
		R.mark_fail(name, "glitch not responding, hi=%f lo=%f" % [hi, lo])
	cons.queue_free()

func _instance_station() -> Node:
	var ps := load("res://levels/TestStation.tscn") as PackedScene
	var st := ps.instantiate()
	add_child(st)
	await get_tree().process_frame
	return st
