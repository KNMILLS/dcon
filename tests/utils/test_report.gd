extends Node
class_name TestReport

var results := []

func mark_pass(name: String) -> void:
	results.append("%s=PASS" % name)
	print("[TEST][PASS]", name)

func mark_fail(name: String, msg: String) -> void:
	results.append("%s=FAIL:%s" % [name, msg])
	push_error("[TEST][FAIL] %s :: %s" % [name, msg])

func write_json() -> void:
	var f := FileAccess.open("user://test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"results": results}, "\t"))


