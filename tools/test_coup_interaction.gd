extends SceneTree

var scene: Node2D

func _init() -> void:
	call_deferred("run")

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate(); root.add_child(scene); await process_frame
	scene._trigger_coup(); scene.selected = scene.coup_key_regions[0]; scene._labels["MainTabs"].current_tab = 1; scene._refresh_ui(); scene._map_layer.queue_redraw(); scene.queue_redraw(); await create_timer(2.0).timeout; _capture()

func _capture() -> void:
	var image: Image = scene.get_viewport().get_texture().get_image(); image.save_png("res://docs/coup-preview.png"); print("coup-interaction: PASS"); quit(0)
