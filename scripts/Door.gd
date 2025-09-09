extends Node3D

@export var powered: bool = true
@export var open_offset: Vector3 = Vector3(0.0, 0.0, -1.5)
@export var slide_time: float = 0.15

var _is_open: bool = false
var _closed_position: Vector3

@onready var _slab: Node3D = $Slab if has_node("Slab") else self
@onready var _body: StaticBody3D = $StaticBody3D if has_node("StaticBody3D") else null
@onready var _shape: CollisionShape3D = $StaticBody3D/CollisionShape3D if has_node("StaticBody3D/CollisionShape3D") else null

func _ready() -> void:
	_closed_position = _slab.position
	name = name if name.begins_with("Door") else "Door_" + name
	add_to_group("Doors")
	_update_collision()

func open() -> void:
	if not powered:
		return
	_is_open = true
	_update_motion()
	_update_collision()

func close() -> void:
	if not powered:
		return
	_is_open = false
	_update_motion()
	_update_collision()

func toggle() -> void:
	if not powered:
		return
	_is_open = not _is_open
	_update_motion()
	_update_collision()

func is_open() -> bool:
	return _is_open

func _update_motion() -> void:
	var offset := open_offset if _is_open else Vector3.ZERO
	var target := _closed_position + offset
	if slide_time <= 0.0:
		_slab.position = target
		return
	var tw := get_tree().create_tween()
	tw.tween_property(_slab, "position", target, slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_collision() -> void:
	if _shape:
		_shape.set_deferred("disabled", _is_open)


