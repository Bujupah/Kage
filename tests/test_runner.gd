extends SceneTree
## Headless test runner. Exits non-zero on failure so CI can gate on it:
##   godot --headless --path . -s res://tests/test_runner.gd
## Script errors raised while a test runs (failed loads, invalid calls) count as failures too, since
## GDScript otherwise aborts the test silently and it would look like a pass.

const TEST_DIR := "res://tests/unit"


class ErrorCollector extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file, line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


func _initialize() -> void:
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		collector.take()
		var script: GDScript = load(TEST_DIR.path_join(file))
		var load_errors := collector.take()
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			total += 1
			failed += 1
			print("  FAIL  %s :: <load>" % file)
			for e in load_errors:
				print("          " + e)
			continue
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			total += 1
			var case: TestCase = script.new()
			case.call(test_name)
			case.failures.append_array(collector.take().map(func(e: String) -> String: return "script error: " + e))
			if case.failures.is_empty():
				print("  ok    %s :: %s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [file, test_name])
				for f in case.failures:
					print("          " + f)
	OS.remove_logger(collector)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
