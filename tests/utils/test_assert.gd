extends Node
class_name TestAssert

func assert_true(cond: bool, name: String, msg: String = "") -> String:
	if cond:
		return "%s=PASS" % name
	return "%s=FAIL:%s" % [name, msg]

func assert_eq(a, b, name: String) -> String:
	return assert_true(a == b, name, "expected %s got %s" % [str(b), str(a)])

func wait_until(predicate: Callable, timeout_s := 2.0, poll := 0.05) -> bool:
	var t := 0.0
	while t < timeout_s:
		if predicate.call():
			return true
		await get_tree().create_timer(poll).timeout
		t += poll
	return false


