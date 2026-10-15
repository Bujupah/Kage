extends SceneTree
## Headless test runner. Exits non-zero on failure so CI can gate on it:
##   godot --headless --path . -s res://tests/test_runner.gd

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var script: GDScript = load(TEST_DIR.path_join(file))
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			total += 1
			var case: TestCase = script.new()
			case.call(test_name)
			if case.failures.is_empty():
				print("  ok    %s :: %s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [file, test_name])
				for f in case.failures:
					print("          " + f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
