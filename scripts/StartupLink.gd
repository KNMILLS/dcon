extends Control
signal finished

func _ready() -> void:
	await get_tree().process_frame
	var label := $Center/Label
	var overlay := $Overlay as ColorRect
	if label:
		await _typewriter(label, "CONNECTING...", 0.05)
		await get_tree().create_timer(0.5).timeout
		await _fade_overlay(overlay, 1.0)
		emit_signal("finished")
		# Add a simple audio hum for atmosphere
		var hum := AudioStreamPlayer.new()
		add_child(hum)
		hum.stream = AudioStreamGenerator.new()
		hum.play()

func _typewriter(label: Label, text: String, delay: float) -> void:
	label.text = ""
	for i in text.length():
		label.text += text[i]
		await get_tree().create_timer(delay).timeout

func _fade_overlay(overlay: ColorRect, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, duration)
	await tw.finished
