extends Node

var _results: Array[String] = []

func _ready() -> void:
	print("[TESTSUITE] Begin TestAll")
	await run_test_drone_spawn()
	await run_test_movement()
	await run_test_camera_binding()
	print("[TESTSUITE][SUMMARY] ", ", ".join(_results))
	get_tree().quit()

func _pass(name: String) -> void:
	_results.append(name + "=PASS")
	print("[TEST][RESULT] PASS "+name)

func _fail(name: String, msg: String) -> void:
	_results.append(name + "=FAIL")
	print("[TEST][RESULT] FAIL "+name+" :: "+msg)

func _instance_station() -> Node:
	var station_scene := load("res://levels/TestStation.tscn") as PackedScene
	var st := station_scene.instantiate()
	add_child(st)
	await get_tree().process_frame
	return st

func run_test_drone_spawn() -> void:
	var name := "DroneSpawn"
	var st := await _instance_station()
	var d := st.get_node_or_null("Drone") as CharacterBody3D
	if d == null:
		_fail(name, "Drone not found")
		st.queue_free(); await get_tree().process_frame; return
	# Collider below
	var from := d.global_transform.origin
	var to := from + Vector3.DOWN * 2.0
	var space := d.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.size() == 0:
		_fail(name, "No collider below drone at spawn; pos="+str(from))
	else:
		_pass(name)
	st.queue_free(); await get_tree().process_frame

func run_test_movement() -> void:
	var name := "Movement3D"
	var st := await _instance_station()
	var d := st.get_node_or_null("Drone") as CharacterBody3D
	if d == null:
		_fail(name, "Drone not found"); st.queue_free(); await get_tree().process_frame; return
	if d.has_method("set_possessed"): d.set_possessed(true)
	await get_tree().process_frame
	var start := d.global_transform.origin
	var t := 0.0
	while t < 0.5:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().process_frame
	var end := d.global_transform.origin
	var moved := end.distance_to(start) > 0.2
	if not moved:
		_fail(name, "No significant displacement: "+str(start)+" -> "+str(end))
	else:
		_pass(name)
	st.queue_free(); await get_tree().process_frame

func run_test_camera_binding() -> void:
	var name := "CameraBinding"
	# Instance OperatorConsole to build monitor and bind feed
	var cons_scene := load("res://scenes/OperatorConsole.tscn") as PackedScene
	var cons := cons_scene.instantiate()
	add_child(cons)
	await get_tree().process_frame
	# Find drone and monitor
	var st := cons.get_node_or_null("SpaceStationInstance")
	var d := st.get_node_or_null("Drone") as CharacterBody3D if st else null
	var cam := d.get_node_or_null("CameraPivot/Camera3D") as Camera3D if d else null
	var mon := cons.find_child("CCTVMonitor", true, false)
	var vp := mon.get_node_or_null("SubViewport") as SubViewport if mon else null
	var vcam := vp.get_node_or_null("ViewportCamera") as Camera3D if vp else null
	if d == null or cam == null or mon == null or vp == null or vcam == null:
		_fail(name, "Missing nodes: d="+str(d)+" cam="+str(cam)+" mon="+str(mon)+" vp="+str(vp)+" vcam="+str(vcam))
		cons.queue_free(); await get_tree().process_frame; return
	# Ensure feed is bound
	if cons.has_method("_apply_feed_to_monitor"):
		cons._apply_feed_to_monitor()
	await get_tree().process_frame
	await get_tree().process_frame
	var same_world := vp.world_3d == cam.get_world_3d()
	# Nudge rotation and ensure vcam follows transform
	Input.action_press("rotate_right")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("rotate_right")
	await get_tree().process_frame
	await get_tree().process_frame
	var cam_xform := cam.global_transform
	var vcam_xform := vcam.global_transform
	var follow_ok := cam_xform.origin.distance_to(vcam_xform.origin) < 0.01 and cam_xform.basis.is_equal_approx(vcam_xform.basis)
	var vp_ok := vp.size.x > 0 and vp.size.y > 0 and vp.get_texture() != null
	if same_world and follow_ok and vp_ok:
		_pass(name)
	else:
		_fail(name, "same_world="+str(same_world)+" follow="+str(follow_ok)+" vp_ok="+str(vp_ok))
	cons.queue_free(); await get_tree().process_frame
