extends CharacterBody3D

const MOUSE_SENSITIVITY := 0.1
const MOVE_SPEED := 5.0
const LOOK_LIMIT_DEGREES := 89.0

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

func _ready() -> void:
	if camera:
		camera.current = false
	if memory:
		memory.pressure_changed.connect(_on_memory_pressure_changed)
	_task_timer = Timer.new()
	_task_timer.autostart = true
	_task_timer.one_shot = false
	add_child(_task_timer)
	_task_timer.timeout.connect(_on_task_tick)
	_update_task_timer()
	# Single-drone: registry removed

func set_possessed(possessed: bool) -> void:
	_is_possessed = possessed
	if possessed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera:
			camera.current = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func apply_look(relative: Vector2) -> void:
	if not _is_possessed:
		return
	_yaw_degrees -= relative.x * MOUSE_SENSITIVITY
	_pitch_degrees -= relative.y * MOUSE_SENSITIVITY
	_pitch_degrees = clamp(_pitch_degrees, -LOOK_LIMIT_DEGREES, LOOK_LIMIT_DEGREES)
	rotation_degrees.y = _yaw_degrees
	camera_pivot.rotation_degrees.x = _pitch_degrees

func _physics_process(_delta: float) -> void:
	if not _is_possessed:
		return
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir += -transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir += -transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized() * MOVE_SPEED
		velocity.x = input_dir.x
		velocity.z = input_dir.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0
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
