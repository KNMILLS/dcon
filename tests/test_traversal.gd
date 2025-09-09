extends Node

const TestReport = preload("res://tests/utils/test_report.gd")

@onready var R: TestReport = TestReport.new()

func _ready() -> void:
	add_child(R)
	await _run_traversal()
	queue_free()

func _find_first_door(root: Node) -> Node:
	for d in root.get_children():
		if d.name.begins_with("Door"):
			return d
		var sub := _find_first_door(d)
		if sub:
			return sub
	return null

func _run_traversal() -> void:
	var name := "M3.Traversal"
	var ps := load("res://levels/TestStation.tscn") as PackedScene
	var st := ps.instantiate()
	# Prevent quit during tests
	if "test_mode" in st:
		st.test_mode = true
	add_child(st)
	await get_tree().process_frame
	var d := st.get_node_or_null("Drone") as CharacterBody3D
	if d == null:
		R.mark_fail(name, "Drone not found")
		st.queue_free()
		return
	if d.has_method("set_possessed"):
		d.set_possessed(true)
	await get_tree().process_frame
	# Move towards corridor end for ~2 seconds to approach door
	var t := 0.0
	while t < 2.0:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().process_frame
	# Interact with door
	if InputMap.has_action("interact") == false:
		InputMap.add_action("interact")
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().process_frame
	# Move forward to pass door
	t = 0.0
	while t < 1.2:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().process_frame
	# Move to extraction: continue forward and then right into room
	t = 0.0
	while t < 2.0:
		Input.action_press("move_forward")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().process_frame
	# Check extraction flag
	var ok := false
	if st.has_variable("extraction_reached"):
		ok = st.extraction_reached
	if ok:
		R.mark_pass(name)
	else:
		R.mark_fail(name, "Extraction not reached")
	st.queue_free()
