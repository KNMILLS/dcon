extends SubViewportContainer

@onready var sub_viewport: SubViewport = $SubViewport
@onready var viewport_camera: Camera3D = $SubViewport/ViewportCamera
var _shader_mat: ShaderMaterial
@onready var _glitch_shader: Shader = preload("res://shaders/glitch_under_load.gdshader")
var _source_camera: Camera3D = null
var _last_diag_time := 0.0
var _last_vp_pos := Vector3.INF
var _last_src_pos := Vector3.INF
signal feed_bound(cam: Camera3D)
@export var enable_debug_logging: bool = false
var _warn_size_once: bool = false
var _warn_cam_once: bool = false
var _warn_tex_once: bool = false

func _ready() -> void:
	# Attach post-process material directly to this CanvasItem
	if _glitch_shader:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = _glitch_shader
		_shader_mat.set_shader_parameter("mode", 0)
		_shader_mat.set_shader_parameter("glitch_intensity", 0.0)
		material = _shader_mat
	# Ensure SubViewport renders
	if sub_viewport:
		# If container has stretch=true, don't set size directly; ensure update mode instead
		if sub_viewport.has_method("set_update_mode"):
			sub_viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		if sub_viewport.has_method("set_clear_mode"):
			sub_viewport.set_clear_mode(SubViewport.CLEAR_MODE_ALWAYS)
		# SubViewportContainer has stretch=true; avoid changing size at runtime
	# Ensure there is an active camera for this viewport
	if is_instance_valid(viewport_camera):
		viewport_camera.current = true
	# Enable processing so we can follow the source camera
	set_process(true)
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
		# Diagnostics: every 0.5s log positions to confirm following
		if enable_debug_logging:
			var t: int = Time.get_ticks_msec()
			if t - _last_diag_time > 500:
				_last_diag_time = t
				var vp_pos: Vector3 = viewport_camera.global_transform.origin
				var src_pos: Vector3 = _source_camera.global_transform.origin
				if _last_vp_pos != Vector3.INF and _last_src_pos != Vector3.INF:
					var dvp: Vector3 = vp_pos - _last_vp_pos
					var dsrc: Vector3 = src_pos - _last_src_pos
					print("[MonitorDiag] vp ", vp_pos, " dvp ", dvp, " | src ", src_pos, " dsrc ", dsrc)
				_last_vp_pos = vp_pos
				_last_src_pos = src_pos
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
			# Immediately sync transform so feed updates without waiting a frame
			viewport_camera.global_transform = cam.global_transform
		if sub_viewport and sub_viewport.size == Vector2i.ZERO:
			sub_viewport.size = Vector2i(640, 360)
		if enable_debug_logging:
			print("[Monitor] Feed bound to camera:", cam.get_path())
		emit_signal("feed_bound", cam)
	else:
		if not _warn_cam_once:
			_warn_cam_once = true
			push_error("[Monitor] No camera found on feed node: %s" % [feed_node])

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
		var r: float = clampf(ratio, 0.0, 1.0)
		_shader_mat.set_shader_parameter("memory_pressure", r)
		_shader_mat.set_shader_parameter("glitch_intensity", r)

func set_visor_mode(mode: int) -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("mode", clamp(mode, 0, 2))

func _update_debug() -> void:
	var lbl: Label = get_node_or_null("DebugLabel") as Label
	if lbl == null:
		return
	var vp_ok: bool = sub_viewport != null and sub_viewport.size.x > 0 and sub_viewport.size.y > 0
	var cam_ok: bool = is_instance_valid(viewport_camera) and viewport_camera.current
	var tex_ok: bool = false
	var w: int = 0
	var h: int = 0
	if sub_viewport != null:
		var tex: ViewportTexture = sub_viewport.get_texture()
		tex_ok = tex != null
		w = sub_viewport.size.x
		h = sub_viewport.size.y
	if enable_debug_logging:
		var cam_str := "yes" if cam_ok else "no"
		var tex_str := "yes" if tex_ok else "no"
		var src_str := str(_source_camera.get_path()) if is_instance_valid(_source_camera) else "none"
		lbl.text = "VP %dx%d | cam:%s | tex:%s | src:%s" % [w, h, cam_str, tex_str, src_str]
		lbl.visible = true
	else:
		lbl.visible = false
	if not vp_ok and not _warn_size_once:
		_warn_size_once = true
		push_error("[Monitor] SubViewport size is 0; set size or update mode.")
	if not cam_ok and not _warn_cam_once:
		_warn_cam_once = true
		push_error("[Monitor] No current Camera3D for SubViewport.")
	if not tex_ok and not _warn_tex_once:
		_warn_tex_once = true
		push_error("[Monitor] SubViewport texture is null.")
