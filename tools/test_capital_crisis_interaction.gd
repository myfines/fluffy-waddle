extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	var national: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(national); await process_frame
	national._trigger_coup(); national._enter_capital_crisis(); await process_frame
	var city = national._capital_crisis; city._unit_select.select(0); city._select_unit(0); city.selected_node = 1; city.queue_redraw(); await create_timer(1.0).timeout
	var image: Image = city.get_viewport().get_texture().get_image(); image.save_png("res://docs/capital-preview.png"); print("capital-interaction: PASS"); quit(0)
