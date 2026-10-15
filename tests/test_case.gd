class_name TestCase
extends RefCounted
## Minimal assertion base for headless tests. A test is any method named test_*.

var failures: Array[String] = []


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("expected true: %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		failures.append("expected false: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected <%s>, got <%s>" % [message, str(expected), str(actual)])
