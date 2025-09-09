extends Node

var _drone: CharacterBody3D
var _station: Node
var _passed: bool = true

func _ready() -> void:
	print("[TEST] Begin TestStationMovement")
	# Ensure input actions exist
	var actions := ["move_forward","move_back","move_left","move_right","rotate_left","rotate_right","possess_toggle"]
	for a in actions:
		if not InputMap.has_action(a): InputMap.add_action(a)
	# Instance station
	var station_scene := load("res://levels/TestStation.tscn") as PackedScene
	_station = station_scene.instantiate()
	add_child(_station)
	await get_tree().process_frame
	# Resolve drone
	_drone = _station.get_node_or_null("Drone") as CharacterBody3D
	if _drone == null:
		print("[TEST][FAIL] Drone not found in station")
		_passed = false
		_finish()
		return
	# Possess and set camera current
	if _drone.has_method("set_possessed"): _drone.set_possessed(true)
	var cam := _drone.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if cam: cam.current = true
	await get_tree().process_frame
	# Collision below drone
	var from := _drone.global_transform.origin
	var to := from + Vector3.DOWN * 2.0
	var space := _drone.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.size() == 0:
		print("[TEST][FAIL] No collider below drone at spawn")
		_passed = false
	# Simulate forward input for 0.5s
	var start := _drone.global_transform.origin
	var t := 0.0
	while t < 0.5:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	var end := _drone.global_transform.origin
	var moved := end.distance_to(start) > 0.05
	if not moved:
		print("[TEST][FAIL] Drone did not move forward: ", start, " -> ", end)
		_passed = false
	else:
		print("[TEST][OK] Movement detected: ", start, " -> ", end)
	_finish()

func _finish() -> void:
	if _passed:
		print("[TEST][RESULT] PASS TestStationMovement")
	else:
		print("[TEST][RESULT] FAIL TestStationMovement")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
