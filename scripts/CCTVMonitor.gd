extends SubViewportContainer

@onready var sub_viewport: SubViewport = $SubViewport
var _shader_mat: ShaderMaterial

func _ready() -> void:
	var sh := load("res://shaders/glitch_under_load.gdshader") as Shader
	if sh:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = sh
		material = _shader_mat

func set_feed(feed_node: Node) -> void:
	# Detach any existing children without freeing them, so we can reuse feeds
	for c in sub_viewport.get_children():
		if c == feed_node:
			continue
		sub_viewport.remove_child(c)
	# Reparent the provided node into this SubViewport safely
	if feed_node.get_parent() and feed_node.get_parent() != sub_viewport:
		feed_node.get_parent().remove_child(feed_node)
	sub_viewport.add_child(feed_node)

func set_memory_pressure(ratio: float) -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("memory_pressure", clamp(ratio, 0.0, 1.0))
