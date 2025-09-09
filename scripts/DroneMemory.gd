@icon("res://icon.svg")
extends Resource
class_name DroneMemory

@export var capacity_mb: float = 64.0
@export var used_mb: float = 0.0
@export var idle_baseline_mb: float = 2.0

signal pressure_changed(ratio: float)

func get_pressure_ratio() -> float:
	if capacity_mb <= 0.0:
		return 0.0
	return clamp(used_mb / capacity_mb, 0.0, 1.0)

func claim(mb: float) -> void:
	if mb <= 0.0:
		return
	used_mb = clamp(used_mb + mb, 0.0, capacity_mb)
	pressure_changed.emit(get_pressure_ratio())

func release(mb: float) -> void:
	if mb <= 0.0:
		return
	used_mb = clamp(used_mb - mb, 0.0, capacity_mb)
	pressure_changed.emit(get_pressure_ratio())

func set_used_mb(value: float) -> void:
	used_mb = clamp(value, 0.0, capacity_mb)
	pressure_changed.emit(get_pressure_ratio())

# ---- Milestone 2: task token helpers ----
var _next_token_id: int = 1
var _token_to_mb: Dictionary = {}

func begin_task(cost_mb: float) -> int:
	# Returns a token id (>=1) or -1 if cost invalid
	if cost_mb <= 0.0:
		return -1
	var token := _next_token_id
	_next_token_id += 1
	_token_to_mb[token] = cost_mb
	claim(cost_mb)
	return token

func end_task(token: int) -> void:
	if token == -1:
		return
	if _token_to_mb.has(token):
		var mb: float = _token_to_mb[token]
		_token_to_mb.erase(token)
		release(mb)

func set_capacity_mb(value: float) -> void:
	capacity_mb = maxf(value, 0.0)
	used_mb = clamp(used_mb, 0.0, capacity_mb)
	pressure_changed.emit(get_pressure_ratio())
