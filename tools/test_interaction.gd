extends SceneTree

var scene: Node2D
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	scene._unhandled_input(event)

func _run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var center: Vector2 = scene._point(float(scene.regions[0].lon), float(scene.regions[0].lat))
	_click(center)
	_check(scene.selected == 0, "地区内点击命中区域")
	_click(Vector2(850, 700))
	_check(scene.selected == -1, "海上空白点击清除选择")
	_click(Vector2(1000, 500))
	_check(scene.selected == -1, "侧栏点击不穿透地图")
	scene._unhandled_input(_key(KEY_SPACE))
	_check(not scene.paused, "空格继续")
	scene._unhandled_input(_key(KEY_SPACE))
	_check(scene.paused, "空格暂停")
	scene._unhandled_input(_key(KEY_2))
	_check(scene.speed == 2.0, "2键速度")
	scene._unhandled_input(_key(KEY_4))
	_check(scene.speed == 4.0, "4键速度")
	scene._unhandled_input(_key(KEY_1))
	_check(scene.speed == 1.0, "1键速度")
	var start_day: int = scene.simulation.day
	scene.paused = false
	scene.speed = 2.0
	scene._process(0.5)
	_check(scene.simulation.day == start_day + 2, "2倍速半秒结算两天")
	var before_residual: int = scene.simulation.day
	scene._process(0.1)
	_check(scene.simulation.day == before_residual, "余数未满一天不推进")
	scene._process(0.15)
	_check(scene.simulation.day == before_residual + 1, "余数累计后推进一天")
	scene._process(0.25)
	_check(scene.simulation.day == before_residual + 2, "再次累计余数后推进一天")
	scene._unhandled_input(_key(KEY_SPACE))
	var paused_day: int = scene.simulation.day
	scene._process(2.0)
	_check(scene.simulation.day == paused_day, "暂停时不推进")
	_click(center)
	_check(scene.selected == 0, "缩放拖动前再次命中")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.position = center
	scene._unhandled_input(wheel)
	var motion := InputEventMouseMotion.new()
	scene._unhandled_input(InputEventMouseButton.new())
	motion.position = center + Vector2(30, 20); motion.relative = Vector2(30, 20)
	scene.dragging = true; scene._unhandled_input(motion); scene.dragging = false
	var moved_center: Vector2 = scene._point(float(scene.regions[0].lon), float(scene.regions[0].lat))
	_click(moved_center)
	_check(scene.selected == 0, "缩放拖动后命中同一区域")
	# Leave the captured review frame in the most useful state: a selected
	# southern district with one real scheduled event waiting for a choice.
	scene.total_days = 28
	scene._start_event()
	scene._refresh_ui()
	RenderingServer.frame_post_draw.connect(_capture)
	scene.queue_redraw()

func _capture() -> void:
	var image: Image = scene.get_viewport().get_texture().get_image()
	image.save_png("res://docs/stage1-preview.png")
	if failures == 0: print("interaction-tests: PASS")
	else: print("interaction-tests: FAIL count=", failures)
	quit(0 if failures == 0 else 1)
