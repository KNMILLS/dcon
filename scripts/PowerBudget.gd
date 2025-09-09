@icon("res://icon.svg")
extends Resource
class_name PowerBudget

@export var capacity_units: float = 100.0
@export var used_units: float = 0.0

signal pressure_changed(ratio: float)

func get_pressure_ratio() -> float:
	if capacity_units <= 0.0:
		return 0.0
	return clamp(used_units / capacity_units, 0.0, 1.0)

func claim(units: float) -> void:
	if units <= 0.0:
		return
	used_units = clamp(used_units + units, 0.0, capacity_units)
	pressure_changed.emit(get_pressure_ratio())

func release(units: float) -> void:
	if units <= 0.0:
		return
	used_units = clamp(used_units - units, 0.0, capacity_units)
	pressure_changed.emit(get_pressure_ratio())

func set_used_units(value: float) -> void:
	used_units = clamp(value, 0.0, capacity_units)
	pressure_changed.emit(get_pressure_ratio())

