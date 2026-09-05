extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var image: Image = scene.get_viewport().get_texture().get_image()
	image.save_png("user://stage1_runtime.png")
	print("runtime-capture: ", ProjectSettings.globalize_path("user://stage1_runtime.png"))
	quit()
