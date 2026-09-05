extends SceneTree

func _p(values: Array[float], percentile: float) -> float:
	values.sort(); return values[mini(values.size() - 1, ceili(values.size() * percentile) - 1)]

func _frame_sample(scene: Node2D, event: InputEvent) -> float:
	var start := Time.get_ticks_usec()
	if event == null: scene.queue_redraw()
	else: scene._unhandled_input(event)
	await process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(scene); await process_frame
	var idle: Array[float] = []; var transforms: Array[float] = []
	for _i in range(60): idle.append(await _frame_sample(scene, null))
	for i in range(60):
		var event: InputEvent
		if i % 2 == 0:
			var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP if i % 4 == 0 else MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true; wheel.position = Vector2(440, 410); event = wheel
		else:
			var motion := InputEventMouseMotion.new(); motion.relative = Vector2(3, -2); scene.dragging = true; event = motion
		transforms.append(await _frame_sample(scene, event))
	scene.dragging = false
	print("frame-performance: idle_samples=60 p50_ms=%.2f p95_ms=%.2f transform_samples=60 p50_ms=%.2f p95_ms=%.2f" % [_p(idle, 0.5), _p(idle, 0.95), _p(transforms, 0.5), _p(transforms, 0.95)])
	quit(0)
