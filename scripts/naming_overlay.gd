extends Control

signal name_confirmed(name: String)
signal name_canceled()

@onready var _edit: LineEdit = $Panel/VBox/NameEdit
@onready var _feedback: Label = $Panel/VBox/Feedback
@onready var _confirm: Button = $Panel/VBox/Buttons/Confirm
@onready var _cancel: Button = $Panel/VBox/Buttons/Cancel

var _target_drone: Node = null
var _suggested_name: String = ""

func _ready() -> void:
	visible = false
	_confirm.pressed.connect(_on_confirm)
	_cancel.pressed.connect(_on_cancel)
	_edit.text_submitted.connect(_on_text_submitted)

func open_for(drone: Node, suggested: String = "") -> void:
	_target_drone = drone
	_suggested_name = suggested if suggested != "" else _generate_suggested_callsign()
	_edit.text = _suggested_name
	_edit.caret_column = _edit.text.length()
	_feedback.text = ""
	visible = true
	_edit.grab_focus()
	get_tree().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_cancel()

func _on_text_submitted(_text: String) -> void:
	_on_confirm()

func _on_confirm() -> void:
	var candidate := _sanitize(_edit.text)
	if not _is_valid(candidate):
		_feedback.text = "NAME REQUIRED"
		return
	emit_signal("name_confirmed", candidate)
	visible = false

func _on_cancel() -> void:
	_feedback.text = "A VALID NAME IS REQUIRED TO PROCEED"
	emit_signal("name_canceled")
	visible = true
	_edit.grab_focus()

func _sanitize(s: String) -> String:
	var t := s.strip_edges()
	# Collapse inner whitespace
	var parts := t.split(" ", false)
	return " ".join(parts)

func _is_valid(s: String) -> bool:
	return s.length() >= 2 and s.length() <= _edit.max_length

func _generate_suggested_callsign() -> String:
	var bank: Array[String] = [
 		"ARGUS", "NOVA", "VIGIL", "SABLE", "ONYX", "LYNX", "KITE",
 		"IRIS", "KRAIT", "DELTA", "ECHO", "TANGO"
 	]
	var index: int = int(randi()) % bank.size()
	var letters: String = bank[index]
	var number: int = int(randi() % 90) + 10
	return "%s %02d" % [letters, number]


