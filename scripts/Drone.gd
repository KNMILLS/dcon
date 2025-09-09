extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 12.0
@export var gravity: float = 9.8

@export var mouse_sensitivity: float = 0.1
@export var look_limit_degrees: float = 89.0

@export var default_fov_deg: float = 75.0
@export var fov_min_deg: float = 55.0
@export var fov_max_deg: float = 85.0
@export var fov_step_deg: float = 5.0
@export var rotate_deg_per_sec: float = 90.0
@export var enable_debug_logging: bool = false

signal memory_pressure_changed(ratio: float)

@export var codename: String = "UNNAMED"
@export var capabilities: PackedStringArray = ["SCAN"]
@export var is_named: bool = false
@export var memory: DroneMemory = DroneMemory.new()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var _is_possessed: bool = false
var _yaw_degrees: float = 0.0
var _pitch_degrees: float = 0.0
var _task_timer: Timer
var _debug_first_tick_logged: bool = false
var _debug_wasd_logged: bool = false
var _debug_rotate_logged: bool = false
var _debug_logged: bool = false
var _debug_look_logged: bool = false

func _ready() -> void:
	if enable_debug_logging:
		print("[Drone] ready")
	add_to_group("PlayerDrone")
	if camera:
		camera.current = false
		camera.fov = clampf(default_fov_deg, fov_min_deg, fov_max_deg)
	if memory:
		memory.pressure_changed.connect(_on_memory_pressure_changed)
	_task_timer = Timer.new()
	_task_timer.autostart = true
	_task_timer.one_shot = false
	add_child(_task_timer)
	_task_timer.timeout.connect(_on_task_tick)
	_update_task_timer()
	# Single-drone: registry removed
	# Confirm input actions exist
	for action in ["move_forward", "move_back", "move_left", "move_right", "rotate_left", "rotate_right"]:
		if not InputMap.has_action(action):
			print("[Drone][WARN] Missing action:", action)

func set_possessed(possessed: bool) -> void:
	_is_possessed = possessed
	if enable_debug_logging:
		print("[Drone] possessed:", possessed)
	if possessed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera:
			camera.current = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func apply_look(relative: Vector2) -> void:
	if not _is_possessed:
		return
	if not _debug_look_logged and (abs(relative.x) > 0.0 or abs(relative.y) > 0.0):
		_debug_look_logged = true
		if enable_debug_logging:
			print("[Drone] mouse look input detected")
	_yaw_degrees -= relative.x * mouse_sensitivity
	_pitch_degrees -= relative.y * mouse_sensitivity
	_pitch_degrees = clamp(_pitch_degrees, -look_limit_degrees, look_limit_degrees)
	rotation_degrees.y = _yaw_degrees
	camera_pivot.rotation_degrees.x = _pitch_degrees

func _physics_process(delta: float) -> void:
	if not _debug_first_tick_logged:
		if enable_debug_logging:
			print("[Drone] physics tick; possessed=", _is_possessed)
		_debug_first_tick_logged = true
	velocity.y -= gravity * delta

	var target_h := Vector2.ZERO
	# Keyboard movement/rotation always active; mouse look still gated by possession
	var rotate_input := 0.0
	if Input.is_action_pressed("rotate_left"):
		rotate_input -= 1.0
	if Input.is_action_pressed("rotate_right"):
		rotate_input += 1.0
	if rotate_input != 0.0:
		if not _debug_rotate_logged:
			if enable_debug_logging:
				print("[Drone] rotate input detected")
			_debug_rotate_logged = true
		_yaw_degrees += rotate_input * rotate_deg_per_sec * delta
		rotation_degrees.y = _yaw_degrees

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		if not _debug_wasd_logged:
			if enable_debug_logging:
				print("[Drone] WASD input detected")
			_debug_wasd_logged = true
	if Input.is_action_pressed("move_forward"):
		input_dir += -transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir += -transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized() * speed
		target_h = Vector2(input_dir.x, input_dir.z)

	var current_h := Vector2(velocity.x, velocity.z)
	var new_h := current_h.move_toward(target_h, acceleration * delta)
	velocity.x = new_h.x
	velocity.z = new_h.y

	move_and_slide()

func _on_memory_pressure_changed(ratio: float) -> void:
	memory_pressure_changed.emit(ratio)
	_update_task_timer()

func _update_task_timer() -> void:
	if _task_timer == null:
		return
	var ratio := 0.0
	if memory:
		ratio = memory.get_pressure_ratio()
	_task_timer.wait_time = lerp(1.0, 3.0, ratio)
	if not _task_timer.is_stopped():
		_task_timer.start()

func _on_task_tick() -> void:
	pass 

func is_possessed() -> bool:
	return _is_possessed

func zoom_in() -> void:
	_set_fov_deg(camera.fov - fov_step_deg)

func zoom_out() -> void:
	_set_fov_deg(camera.fov + fov_step_deg)

func _set_fov_deg(value: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.fov = clampf(value, fov_min_deg, fov_max_deg)
