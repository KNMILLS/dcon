extends Control
signal finished

func _ready() -> void:
	await get_tree().process_frame
	var label := $Center/Label
	var overlay := $Overlay as ColorRect
	if label:
		var boot_text: String = label.text
		await _typewriter(label, boot_text, 0.05)
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
	var lines := text.split("\n")
	for l in lines:
		for i in l.length():
			label.text += l[i]
			await get_tree().create_timer(delay).timeout
		label.text += "\n"
		var pause := 0.12
		if l.find("INIT SEQUENCE BEGIN") != -1 or l.find("Signal lock confirmed") != -1 or l.find("INIT SEQUENCE COMPLETE") != -1:
			pause = 0.35
		elif l.strip_edges() == "":
			pause = 0.20
		await get_tree().create_timer(pause).timeout

func _fade_overlay(overlay: ColorRect, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, duration)
	await tw.finished
