extends Node2D

var host: Node
var geometry_build_ms := 0.0
var last_draw_ms := 0.0
var _cache: Array = []

func build_geometry_cache() -> void:
	var started := Time.get_ticks_usec()
	_cache.clear()
	for region_index in host.regions.size():
		var region: Dictionary = host.regions[region_index]
		var ring_index := 0
		for ring in region.rings:
			var poly := PackedVector2Array()
			for point in ring:
				var p: Vector2 = host._point_local_base(float(point[0]), float(point[1]))
				if poly.is_empty() or p.distance_squared_to(poly[poly.size() - 1]) > 0.0001: poly.append(p)
			if poly.size() > 1 and poly[0].distance_squared_to(poly[poly.size() - 1]) <= 0.0001: poly.remove_at(poly.size() - 1)
			if poly.size() >= 3:
				var indices := Geometry2D.triangulate_polygon(poly)
				var segments: Array = []
				if indices.size() >= 3 and indices.size() % 3 == 0: segments = _scanline_segments(poly)
				_cache.append({"region": region_index, "ring": ring_index, "poly": poly, "indices": indices, "segments": segments})
			ring_index += 1
	geometry_build_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _scanline_segments(poly: PackedVector2Array) -> Array:
	var min_y := poly[0].y; var max_y := poly[0].y
	for p in poly: min_y = minf(min_y, p.y); max_y = maxf(max_y, p.y)
	var segments: Array = []; var y := floori(min_y)
	while y <= ceili(max_y):
		var xs: Array[float] = []
		for i in range(poly.size()):
			var a := poly[i]; var b := poly[(i + 1) % poly.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y): xs.append(a.x + (float(y) - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			if i + 1 < xs.size(): segments.append([Vector2(xs[i], y), Vector2(xs[i + 1], y)])
		y += 2
	return segments

func _draw() -> void:
	var started := Time.get_ticks_usec()
	for item in _cache:
		var region: Dictionary = host.regions[item.region]
		var fill := _region_color(region)
		for segment in item.segments: draw_line(segment[0], segment[1], Color(fill, 0.58), 2.0, false)
		var outline: PackedVector2Array = item.poly.duplicate(); outline.append(outline[0])
		var line_color := Color("f6d365") if host.selected >= 0 and host.regions[host.selected].id == region.id else Color("687b7c")
		draw_polyline(outline, line_color, 0.75, true)
	for unit in host.units:
		var p: Vector2 = host._point_local_base(float(host.regions[unit.region].lon), float(host.regions[unit.region].lat))
		var unit_color := Color("e0b04f") if unit.side == "government" else Color("c4575e") if unit.side == "coup" else Color("9da8a9")
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), unit_color, true)
		if host.selected_unit == unit.id: draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("f8e7a8"), false, 1.5)
	last_draw_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _region_color(region: Dictionary) -> Color:
	if host.map_mode == "support": return Color("b64f52").lerp(Color("4dba8e"), clampf(float(region.support) / 100.0, 0.0, 1.0))
	if host.map_mode == "insurgency": return Color("4dba8e").lerp(Color("c84f55"), clampf(float(region.insurgency) / 100.0, 0.0, 1.0))
	return Color("a04e57") if region.faction == "north" else Color("397f70")
