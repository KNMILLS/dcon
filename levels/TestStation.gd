extends Node3D

# Phase 1 blockout builder for TestStation.
# References:
# - GridMap + MeshLibrary pipeline and stamping; meshes include collision & nav shapes in MeshLibrary. (Godot Docs)
# - StaticBody3D + CollisionShape3D usage. (Godot Docs)
# - WorldEnvironment tonemapping/fog. (Godot Docs)
# - NavigationRegion3D baking: defer baking, avoid same-frame edits; use simple sources. (Godot Docs / Forum)
# - Occlusion culling reserved for later.

@onready var grid: GridMap = $GridMap
@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var drone_spawn: Marker3D = $DroneSpawn

var _meshlib: MeshLibrary
var _first_run_done := false

const TILE_SIZE := 2.0

func _ready() -> void:
	_ensure_actions()
	_build_mesh_library()
	_assign_mesh_library()
	_stamp_layout()
	_bake_runtime_colliders()
	_position_spawn_on_floor()
	# Optional navmesh bake deferred
	if is_instance_valid(nav_region):
		call_deferred("_bake_navmesh_deferred")
	# Diagnostics after layout built
	call_deferred("_print_diagnostics")

func _ensure_actions() -> void:
	var to_add: Array = [
		{"name": "move_forward", "keys": [KEY_W]},
		{"name": "move_back", "keys": [KEY_S]},
		{"name": "move_left", "keys": [KEY_A]},
		{"name": "move_right", "keys": [KEY_D]},
		{"name": "rotate_left", "keys": [KEY_E]},
		{"name": "rotate_right", "keys": [KEY_Q]}
	]
	for item in to_add:
		var action := String(item["name"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if item.has("keys"):
			for key in item["keys"]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


func _build_mesh_library() -> void:
	_meshlib = MeshLibrary.new()
	var id := 0
	# Floor_2x2
	id = _add_box_item(id, "Floor_2x2", Vector3(TILE_SIZE, 0.2, TILE_SIZE), Vector3(0, -0.1, 0))
	# Wall_2x2 (thin along X)
	id = _add_box_item(id, "Wall_2x2", Vector3(0.2, 2.5, TILE_SIZE), Vector3(0, 1.25, 0))
	# DoorFrame_2x2 (wider opening, use thin wall pair with gap)
	id = _add_doorframe_item(id, "DoorFrame_2x2")
	# Corner_2x2 (L-shape composed of two thin walls)
	id = _add_corner_item(id, "Corner_2x2")
	# Ceiling_2x2
	id = _add_box_item(id, "Ceiling_2x2", Vector3(TILE_SIZE, 0.2, TILE_SIZE), Vector3(0, 2.5 + 0.1, 0))

func _add_box_item(next_id: int, item_name: String, size: Vector3, offset: Vector3) -> int:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	var id := next_id
	_meshlib.create_item(id)
	_meshlib.set_item_name(id, item_name)
	_meshlib.set_item_mesh(id, mesh)
	# Collision from MeshLibrary so GridMap auto-places colliders
	_meshlib.set_item_shapes(id, [
		{
			"shape": shape,
			"transform": Transform3D(Basis(), offset),
			"disabled": false
		}
	])
	# Navmesh is deferred/optional; rely on simple collisions for baking
	return id + 1

func _add_doorframe_item(next_id: int, item_name: String) -> int:
	# Doorframe is two thin walls left/right; collision as two shapes
	var half_depth := TILE_SIZE * 0.5
	var wall_half_width := 0.2
	var height := 2.5
	var wall_depth := TILE_SIZE
	var mesh := ArrayMesh.new()
	# Visuals minimal: two boxes merged for preview; collisions carry blocking
	# Left box
	var left := BoxMesh.new(); left.size = Vector3(wall_half_width, height, wall_depth)
	var right := BoxMesh.new(); right.size = Vector3(wall_half_width, height, wall_depth)
	# Combine surfaces into array mesh (visual only)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, left.get_mesh_arrays())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, right.get_mesh_arrays())
	var id := next_id
	_meshlib.create_item(id)
	_meshlib.set_item_name(id, item_name)
	_meshlib.set_item_mesh(id, mesh)
	var shape := BoxShape3D.new(); shape.size = Vector3(wall_half_width, height, wall_depth)
	_meshlib.set_item_shapes(id, [
		{"shape": shape, "transform": Transform3D(Basis(), Vector3(-TILE_SIZE*0.5 + wall_half_width*0.5, height*0.5, 0)), "disabled": false},
		{"shape": shape, "transform": Transform3D(Basis(), Vector3(TILE_SIZE*0.5 - wall_half_width*0.5, height*0.5, 0)), "disabled": false}
	])
	return id + 1

func _add_corner_item(next_id: int, item_name: String) -> int:
	var height := 2.5
	var thickness := 0.2
	var mesh := ArrayMesh.new()
	var a := BoxMesh.new(); a.size = Vector3(TILE_SIZE, height, thickness)
	var b := BoxMesh.new(); b.size = Vector3(thickness, height, TILE_SIZE)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a.get_mesh_arrays())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.get_mesh_arrays())
	var id := next_id
	_meshlib.create_item(id)
	_meshlib.set_item_name(id, item_name)
	_meshlib.set_item_mesh(id, mesh)
	var shape_a := BoxShape3D.new(); shape_a.size = a.size
	var shape_b := BoxShape3D.new(); shape_b.size = b.size
	_meshlib.set_item_shapes(id, [
		{"shape": shape_a, "transform": Transform3D(Basis(), Vector3(0, height*0.5, -TILE_SIZE*0.5 + thickness*0.5)), "disabled": false},
		{"shape": shape_b, "transform": Transform3D(Basis(), Vector3(-TILE_SIZE*0.5 + thickness*0.5, height*0.5, 0)), "disabled": false}
	])
	return id + 1

func _assign_mesh_library() -> void:
	grid.mesh_library = _meshlib
	grid.cell_size = Vector3(TILE_SIZE, TILE_SIZE, TILE_SIZE)
	grid.cell_octant_size = 8
	# Ensure physics layers are active for GridMap collisions
	grid.collision_layer = 1
	grid.collision_mask = 1

func _set_cell(ix: int, iy: int, iz: int, item_name: String) -> void:
	for id in _meshlib.get_item_list():
		if _meshlib.get_item_name(id) == item_name:
			grid.set_cell_item(Vector3i(ix, iy, iz), id)
			return
	push_warning("[TestStation] Item not found: %s" % item_name)

func _stamp_layout() -> void:
	# Simple corridor (10 long) -> tee -> two rooms. Floor + walls + ceiling.
	var y := 0
	# Rooms centered around origin for simplicity
	var start_x := -5
	var end_x := 5
	var z := 0
	for x in range(start_x, end_x + 1):
		_set_cell(x, y, z, "Floor_2x2")
		_set_cell(x, y + 1, z, "Ceiling_2x2")
		# side walls
		_set_cell(x, y, z - 1, "Wall_2x2")
		_set_cell(x, y, z + 1, "Wall_2x2")
	# Tee junction
	for dz in range(-4, 5):
		_set_cell(end_x, y, z + dz, "Floor_2x2")
		_set_cell(end_x, y, z + dz, "Ceiling_2x2")
		_set_cell(end_x - 1, y, z + dz, "Wall_2x2")
		_set_cell(end_x + 1, y, z + dz, "Wall_2x2")
	# Left room
	for x in range(start_x - 6, start_x):
		for dz in range(-4, 5):
			_set_cell(x, y, z + dz, "Floor_2x2")
			_set_cell(x, y, z + dz, "Ceiling_2x2")
			if dz == -4 or dz == 4:
				_set_cell(x, y, z + dz, "Wall_2x2")
			if x == start_x - 6 or x == start_x - 1:
				_set_cell(x, y, z + dz, "Wall_2x2")
	# Right room
	for x in range(end_x + 1, end_x + 7):
		for dz in range(-4, 5):
			_set_cell(x, y, z + dz, "Floor_2x2")
			_set_cell(x, y, z + dz, "Ceiling_2x2")
			if dz == -4 or dz == 4:
				_set_cell(x, y, z + dz, "Wall_2x2")
			if x == end_x + 1 or x == end_x + 6:
				_set_cell(x, y, z + dz, "Wall_2x2")
	# Place a doorframe at corridor end
	_set_cell(end_x, y, z, "DoorFrame_2x2")
	# Position spawn near corridor start; snap to floor and raise by capsule half-height (~0.6)
	var spawn_x := (start_x + 1) * TILE_SIZE
	var spawn_z := z * TILE_SIZE
	var ray_from := Vector3(spawn_x, 5.0, spawn_z)
	var ray_to := Vector3(spawn_x, -5.0, spawn_z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from, ray_to))
	var floor_y := 0.0
	if hit.size() > 0 and hit.has("position"):
		floor_y = hit["position"].y
	drone_spawn.global_transform.origin = Vector3(spawn_x, floor_y + 0.6, spawn_z)
	var d := get_node_or_null("Drone")
	if d:
		d.global_transform = drone_spawn.global_transform

func _bake_runtime_colliders() -> void:
	# Force-convert used GridMap cells to StaticBody3D/CollisionShape3D siblings as a fallback
	# This ensures collisions even if MeshLibrary shapes arenât picked up by GridMap (dev-only)
	var used := grid.get_used_cells()
	for cell in used:
		var it := grid.get_cell_item(cell)
		if it >= 0:
			var name := _meshlib.get_item_name(it)
			if name.begins_with("Floor") or name.begins_with("Wall"):
				var body := StaticBody3D.new()
				body.collision_layer = 1
				body.collision_mask = 1
				add_child(body)
				var shape := CollisionShape3D.new()
				var is_floor := name.begins_with("Floor")
				var size := Vector3(TILE_SIZE, 0.2, TILE_SIZE) if is_floor else Vector3(0.2, 2.5, TILE_SIZE)
				shape.shape = BoxShape3D.new()
				(shape.shape as BoxShape3D).size = size
				var pos := Vector3(cell.x * TILE_SIZE, 0.0, cell.z * TILE_SIZE)
				if is_floor:
					pos.y = -0.1
				else:
					pos.y = 1.25
				body.global_transform.origin = pos
				body.add_child(shape)

func _position_spawn_on_floor() -> void:
	var spawn_x := drone_spawn.global_transform.origin.x
	var spawn_z := drone_spawn.global_transform.origin.z
	var ray_from := Vector3(spawn_x, 5.0, spawn_z)
	var ray_to := Vector3(spawn_x, -5.0, spawn_z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from, ray_to))
	var floor_y := 0.0
	if hit.size() > 0 and hit.has("position"):
		floor_y = hit["position"].y
	drone_spawn.global_transform.origin = Vector3(spawn_x, floor_y + 0.6, spawn_z)
	var d := get_node_or_null("Drone")
	if d:
		d.global_transform = drone_spawn.global_transform

func _bake_navmesh_deferred() -> void:
	if not is_instance_valid(nav_region):
		return
	if nav_region.navigation_mesh == null:
		nav_region.navigation_mesh = NavigationMesh.new()
	# Bake off-thread to avoid hitches
	var t := Time.get_ticks_msec()
	nav_region.bake_navigation_mesh(true)
	var dt := Time.get_ticks_msec() - t
	print("[NavMesh] Bake requested (async). Start ms=", t, " duration_est=", dt)

func _print_diagnostics() -> void:
	if _first_run_done:
		return
	_first_run_done = true
	var cell_count := grid.get_used_cells().size() if is_instance_valid(grid) else 0
	var items_count := _meshlib.get_item_list().size() if _meshlib else 0
	print("[StationDiag] GridMap used cells=", cell_count, " | MeshLibrary items=", items_count)
	# Feed health diagnostics (monitor lives in OperatorConsole)
	var console := get_tree().get_first_node_in_group("OperatorConsole")
	if console == null:
		print("[StationDiag] No OperatorConsole found; feed check skipped")
	else:
		var mon := console.get_node_or_null("CCTVMonitor")
		if mon:
			if mon.has_node("SubViewport"):
				var vp := mon.get_node("SubViewport") as SubViewport
				print("[StationDiag] SubViewport size=", vp.size)
		# Collider under drone
	var drone := get_tree().get_first_node_in_group("PlayerDrone")
	if drone == null:
		var parent := get_parent()
		if parent != null:
			drone = parent.get_node_or_null("Drone")
	if drone and drone is CharacterBody3D:
		var from := (drone as CharacterBody3D).global_transform.origin
		var to := from + Vector3.DOWN * 2.0
		var space := get_world_3d().direct_space_state
		var res := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		print("[StationDiag] Collider below drone? ", res.size() > 0)
