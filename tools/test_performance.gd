extends SceneTree

func _init() -> void:
	call_deferred("run")

func _p95(values: Array[float]) -> float:
	values.sort()
	return values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)]

func run() -> void:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(scene); await process_frame
	var uncached_start := Time.get_ticks_usec(); scene._map_layer.build_geometry_cache(); var uncached_ms := float(Time.get_ticks_usec() - uncached_start) / 1000.0
	var redraw_samples: Array[float] = []
	for _i in range(20):
		scene._map_layer.queue_redraw(); await process_frame; redraw_samples.append(float(scene._map_layer.last_draw_ms))
	var interaction_samples: Array[float] = []
	for i in range(10):
		scene.zoom = 1.0 + float(i % 3) * 0.15; scene.offset = Vector2(i * 4, -i * 2); scene._sync_map_transform(); scene._map_layer.queue_redraw(); await process_frame; interaction_samples.append(float(scene._map_layer.last_draw_ms))
	print("performance: geometry_rebuild_ms=%.2f cached_draw_p95_ms=%.2f transform_draw_p95_ms=%.2f" % [uncached_ms, _p95(redraw_samples), _p95(interaction_samples)])
	quit(0)
