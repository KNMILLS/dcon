extends SubViewportContainer

@onready var sub_viewport: SubViewport = $SubViewport
@onready var viewport_camera: Camera3D = $SubViewport/ViewportCamera
var _shader_mat: ShaderMaterial
var _source_camera: Camera3D = null

func _ready() -> void:
	var sh := load("res://shaders/glitch_under_load.gdshader") as Shader
	if sh:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = sh
		material = _shader_mat
	# Ensure SubViewport renders
	if sub_viewport:
		if sub_viewport.size == Vector2i.ZERO:
			sub_viewport.size = Vector2i(640, 360)
		if sub_viewport.has_method("set_update_mode"):
			sub_viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		if sub_viewport.has_method("set_clear_mode"):
			sub_viewport.set_clear_mode(SubViewport.CLEAR_MODE_ALWAYS)
	# Ensure there is an active camera for this viewport
	if is_instance_valid(viewport_camera):
		viewport_camera.current = true
	# Add simple on-screen diagnostics label
	if get_node_or_null("DebugLabel") == null:
		var lbl := Label.new()
		lbl.name = "DebugLabel"
		lbl.modulate = Color(0.8, 1.0, 0.8, 0.8)
		lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		add_child(lbl)

func _process(_delta: float) -> void:
	if is_instance_valid(_source_camera) and is_instance_valid(viewport_camera):
		viewport_camera.global_transform = _source_camera.global_transform
	_update_debug()

func set_feed(feed_node: Node) -> void:
	# Try to resolve a Camera3D from the feed node
	var cam: Camera3D = null
	if feed_node is Camera3D:
		cam = feed_node
	else:
		cam = feed_node.get_node_or_null("Camera3D") as Camera3D
		if cam == null:
			cam = feed_node.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	_source_camera = cam
	if cam:
		# Render the same world as the source camera
		sub_viewport.world_3d = cam.get_world_3d()
		_copy_camera_settings(cam)
		# Make sure viewport has an active camera
		if is_instance_valid(viewport_camera):
			viewport_camera.current = true
		if sub_viewport and sub_viewport.size == Vector2i.ZERO:
			sub_viewport.size = Vector2i(640, 360)

func _copy_camera_settings(cam: Camera3D) -> void:
	if not is_instance_valid(viewport_camera):
		return
	viewport_camera.fov = cam.fov
	viewport_camera.near = cam.near
	viewport_camera.far = cam.far
	viewport_camera.projection = cam.projection
	viewport_camera.size = cam.size

func set_memory_pressure(ratio: float) -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("memory_pressure", clamp(ratio, 0.0, 1.0))

func _update_debug() -> void:
	var lbl := get_node_or_null("DebugLabel") as Label
	if lbl == null:
		return
	var vp_ok := sub_viewport != null and sub_viewport.size.x > 0 and sub_viewport.size.y > 0
	var cam_ok := is_instance_valid(viewport_camera) and viewport_camera.current
	var tex_ok := false
	var w := 0
	var h := 0
	if sub_viewport != null:
		var tex := sub_viewport.get_texture()
		tex_ok = tex != null
		w = sub_viewport.size.x
		h = sub_viewport.size.y
	var cam_str := "yes" if cam_ok else "no"
	var tex_str := "yes" if tex_ok else "no"
	lbl.text = "VP %dx%d | cam:%s | tex:%s" % [w, h, cam_str, tex_str]
	if not vp_ok:
		push_error("[Monitor] SubViewport size is 0; set size or update mode.")
	if not cam_ok:
		push_error("[Monitor] No current Camera3D for SubViewport.")
	if not tex_ok:
		push_error("[Monitor] SubViewport texture is null.")
