@icon("res://icon.svg")
extends Resource
class_name DroneMemory

@export var capacity_mb: float = 64.0
@export var used_mb: float = 0.0

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
