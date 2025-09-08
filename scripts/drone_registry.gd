extends Node

signal drone_registered(drone)
signal drone_named(drone, codename)

var _drones: Array = []

func register(drone: Node) -> void:
	if _drones.has(drone):
		return
	_drones.append(drone)
	emit_signal("drone_registered", drone)

func get_all_drones() -> Array:
	return _drones.duplicate()

func _has_property(o: Object, prop: String) -> bool:
	for p in o.get_property_list():
		if p.has("name") and String(p["name"]) == prop:
			return true
	return false

func get_unnamed_drones() -> Array:
	var res: Array = []
	for d in _drones:
		if _has_property(d, "is_named") and not d.is_named:
			res.append(d)
	return res

func mark_named(drone: Node) -> void:
	if drone == null:
		return
	if _has_property(drone, "is_named"):
		drone.is_named = true
	if _has_property(drone, "codename"):
		emit_signal("drone_named", drone, String(drone.codename))
		print("[Registry] Drone named: %s" % [String(drone.codename)])


