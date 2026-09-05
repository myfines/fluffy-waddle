extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const DATA_PATH := "res://data/frontier_regions.json"
const DEMO_DATA_PATH := "res://data/demo_regions.json"
const MAP_RECT := Rect2(24, 92, 850, 654)
const LON_MIN := 102.0
const LON_MAX := 110.5
const LAT_MIN := 8.0
const LAT_MAX := 24.0
const ACTION_COSTS := {
	"support": {"budget": 8, "politics": 4, "label": "改善民生"},
	"security": {"budget": 10, "politics": 4, "label": "恢复治安"},
	"politics": {"budget": 6, "politics": 8, "label": "地方协商"},
}
const EVENT_DEFS := [
	{"title": "军方要求增加预算", "a": {"label": "批准军费 · 预算 -20", "budget": 20, "politics": 0, "faction": "军方", "delta": 8, "other": "民间力量", "other_delta": -5}, "b": {"label": "公开审计 · 政治 -6", "budget": 0, "politics": 6, "faction": "军方", "delta": -8, "other": "民间力量", "other_delta": 4}},
	{"title": "地方任命引发派系竞争", "a": {"label": "优先官僚 · 政治 -8", "budget": 0, "politics": 8, "faction": "地方官僚", "delta": 8, "other": "民间力量", "other_delta": -4}, "b": {"label": "民间遴选 · 预算 -12", "budget": 12, "politics": 0, "faction": "民间力量", "delta": 7, "other": "地方官僚", "other_delta": -5}},
	{"title": "民间抗议扩大", "a": {"label": "扩大救济 · 预算 -15", "budget": 15, "politics": 0, "faction": "民间力量", "delta": 9, "other": "军方", "other_delta": -4}, "b": {"label": "治安处置 · 预算 -5", "politics": 0, "budget": 5, "faction": "军方", "delta": 6, "other": "民间力量", "other_delta": -9}},
]

var regions: Array = []
var selected := -1
var paused := true
var speed := 1.0
var elapsed := 0.0
var simulation = Simulation.new()
var zoom := 1.0
var offset := Vector2.ZERO
var dragging := false
var budget := 100
var political_capital := 60
var feedback := "请选择一个南方地区开始治理"
var faction_support := {"军方": 58, "地方官僚": 52, "民间力量": 46}
var stability := 62
var talk_cooldown := 0
var total_days := 0
var event_index := 0
var active_event := ""
var active_event_data: Dictionary = {}
var ended := false
var outcome := ""
var map_mode := "faction"
var _initial_regions: Array = []
var _map_layer
var _map_texture: TextureRect
var _labels: Dictionary = {}
var units: Array = []
var selected_unit := -1
var coup_state := "stable"
var coup_turns := 0
var coup_progress := {"government": 0, "coup": 0}
var player_side := "government"
var coup_key_regions: Array = []
var coup_key_names := ["首都", "电台", "军营"]
var _capital_crisis
var _capital_layer: CanvasLayer

func _ready() -> void:
	var source_path := DATA_PATH if FileAccess.file_exists(DATA_PATH) else DEMO_DATA_PATH
	var payload = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if payload == null or (source_path == DATA_PATH and payload.get("regionCount", 0) != 710):
		push_error("前线区域数据校验失败")
		return
	regions = payload.regions
	for r in regions:
		r.faction = "north" if float(r.lat) >= 17.0 else "south"
	_initial_regions = regions.duplicate(true)
	_find_coup_key_regions()
	_init_units()
	selected = 0
	_build_controls()
	_build_map_layer()
	_map_layer.build_geometry_cache()
	_sync_map_transform()
	_refresh_ui()
	queue_redraw()

func _build_map_layer() -> void:
	var clip := Control.new()
	clip.name = "MapViewport"
	clip.position = MAP_RECT.position
	clip.size = MAP_RECT.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var viewport := SubViewport.new()
	viewport.name = "StaticMapViewport"
	viewport.size = MAP_RECT.size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	clip.add_child(viewport)
	_map_layer = load("res://scripts/map_layer.gd").new()
	_map_layer.name = "MapLayer"
	_map_layer.host = self
	viewport.add_child(_map_layer)
	_map_texture = TextureRect.new()
	_map_texture.name = "MapTexture"
	_map_texture.texture = viewport.get_texture()
	_map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_texture.size = MAP_RECT.size
	clip.add_child(_map_texture)

func _init_units() -> void:
	var south_pool: Array = []
	for i in regions.size():
		if regions[i].faction == "south": south_pool.append(i)
	if south_pool.is_empty(): south_pool.append(0)
	units = [
		{"id": 0, "name": "首都卫队", "side": "government", "region": 0, "strength": 24},
		{"id": 1, "name": "湄公河旅", "side": "government", "region": 45, "strength": 18},
		{"id": 2, "name": "西贡机动队", "side": "government", "region": 120, "strength": 20},
		{"id": 3, "name": "中央高地旅", "side": "government", "region": 180, "strength": 16},
		{"id": 4, "name": "海岸警备队", "side": "government", "region": 250, "strength": 12},
		{"id": 5, "name": "装甲团一部", "side": "coup", "region": south_pool[2 % south_pool.size()], "strength": 22},
		{"id": 6, "name": "空降营", "side": "coup", "region": south_pool[3 % south_pool.size()], "strength": 16},
		{"id": 7, "name": "宪兵队", "side": "coup", "region": south_pool[4 % south_pool.size()], "strength": 14},
		{"id": 8, "name": "地方预备队", "side": "neutral", "region": south_pool[5 % south_pool.size()], "strength": 15},
		{"id": 9, "name": "边境守备队", "side": "neutral", "region": south_pool[6 % south_pool.size()], "strength": 12},
	]
	for unit in units: unit.region = int(unit.region) % maxi(1, regions.size())

func _find_coup_key_regions() -> void:
	coup_key_regions.clear()
	for target in [Vector2(106.7, 10.8), Vector2(105.8, 10.5), Vector2(107.3, 10.5)]:
		var best := 0; var best_distance := INF
		for i in regions.size():
			if regions[i].faction != "south": continue
			var distance := Vector2(float(regions[i].lon), float(regions[i].lat)).distance_squared_to(target)
			if distance < best_distance and not coup_key_regions.has(i): best = i; best_distance = distance
		coup_key_regions.append(best)

func _point(lon: float, lat: float) -> Vector2:
	var scale := minf(MAP_RECT.size.x / (LON_MAX - LON_MIN), MAP_RECT.size.y / (LAT_MAX - LAT_MIN))
	var map_size := Vector2((LON_MAX - LON_MIN) * scale, (LAT_MAX - LAT_MIN) * scale) * zoom
	var origin := MAP_RECT.get_center() - map_size * 0.5 + offset
	return origin + Vector2((lon - LON_MIN) * scale, (LAT_MAX - lat) * scale) * zoom

func _point_local(lon: float, lat: float) -> Vector2:
	return _point(lon, lat) - MAP_RECT.position

func _point_local_base(lon: float, lat: float) -> Vector2:
	var scale := minf(MAP_RECT.size.x / (LON_MAX - LON_MIN), MAP_RECT.size.y / (LAT_MAX - LAT_MIN))
	var base_size := Vector2((LON_MAX - LON_MIN) * scale, (LAT_MAX - LAT_MIN) * scale)
	var origin := MAP_RECT.get_center() - base_size * 0.5
	return origin + Vector2((lon - LON_MIN) * scale, (LAT_MAX - lat) * scale) - MAP_RECT.position

func _sync_map_transform() -> void:
	if _map_texture == null: return
	var center := MAP_RECT.size * 0.5
	_map_texture.scale = Vector2.ONE * zoom
	_map_texture.position = center + offset - center * zoom

func _unproject(pos: Vector2) -> Vector2:
	var scale := minf(MAP_RECT.size.x / (LON_MAX - LON_MIN), MAP_RECT.size.y / (LAT_MAX - LAT_MIN))
	var map_size := Vector2((LON_MAX - LON_MIN) * scale, (LAT_MAX - LAT_MIN) * scale) * zoom
	var origin := MAP_RECT.get_center() - map_size * 0.5 + offset
	return (pos - origin) / (scale * zoom)

func _clamp_view() -> void:
	var scale := minf(MAP_RECT.size.x / (LON_MAX - LON_MIN), MAP_RECT.size.y / (LAT_MAX - LAT_MIN))
	var map_size := Vector2((LON_MAX - LON_MIN) * scale, (LAT_MAX - LAT_MIN) * scale) * zoom
	var limit := (map_size - MAP_RECT.size) * 0.5 + Vector2(40, 40)
	offset.x = clampf(offset.x, -maxf(limit.x, 40), maxf(limit.x, 40))
	offset.y = clampf(offset.y, -maxf(limit.y, 40), maxf(limit.y, 40))

func _style_panel(color: Color, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius; style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius
	style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color("33464c")
	style.content_margin_left = 14; style.content_margin_right = 14; style.content_margin_top = 10; style.content_margin_bottom = 10
	return style

func _label(name: String, text: String, size := 14, color := Color("d8e2e3")) -> Label:
	var label := Label.new()
	label.name = name; label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color)
	_labels[name] = label
	return label

func _build_controls() -> void:
	var layer := CanvasLayer.new(); layer.name = "Interface"; add_child(layer)
	var panel := PanelContainer.new(); panel.name = "GovernancePanel"; panel.position = Vector2(900, 84); panel.size = Vector2(348, 680)
	panel.add_theme_stylebox_override("panel", _style_panel(Color("111d22"))); layer.add_child(panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 12); margin.add_theme_constant_override("margin_right", 12); margin.add_theme_constant_override("margin_top", 10); margin.add_theme_constant_override("margin_bottom", 10); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 7); margin.add_child(box)
	box.add_child(_label("Title", "南方执政 · 治理控制", 19, Color("f4d47d")))
	box.add_child(_label("Resources", "", 15, Color("eef4f4")))
	box.add_child(_label("Factions", "", 13, Color("b9c9cc")))
	box.add_child(_label("Status", "", 13, Color("9fc5af")))
	box.add_child(_label("Guide", "新手三步：①选南方地区　②执行治理　③每周观察稳定度", 11, Color("d7c47a")))
	box.add_child(_label("NextStep", "建议：先改善民生，再恢复治安", 12, Color("a9d4b5")))
	var pause_button := Button.new(); pause_button.name = "PauseButton"; pause_button.text = "暂停模拟"; pause_button.pressed.connect(_toggle_pause); box.add_child(pause_button)
	_labels["PauseButton"] = pause_button
	var speed_row := HBoxContainer.new(); box.add_child(speed_row)
	for value in [1.0, 2.0, 4.0]:
		var speed_button := Button.new(); speed_button.text = "%sx" % value; speed_button.pressed.connect(func(v=value): speed = v; _refresh_ui()); speed_row.add_child(speed_button)
	var tabs := TabContainer.new(); tabs.name = "MainTabs"; tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(tabs); _labels["MainTabs"] = tabs
	var gov_box := VBoxContainer.new(); gov_box.name = "治理"; gov_box.add_theme_constant_override("separation", 7); tabs.add_child(gov_box)
	var coup_box := VBoxContainer.new(); coup_box.name = "政变"; coup_box.add_theme_constant_override("separation", 7); tabs.add_child(coup_box)
	gov_box.add_child(_label("ModeTitle", "地图显示：阵营 / 民心 / 叛乱", 14, Color("f4d47d")))
	gov_box.add_child(_label("Legend", "图例：青色=南方　红色=北方/高叛乱　民心模式由红到绿", 11, Color("a9b9bd")))
	var focus_south := Button.new(); focus_south.name = "FocusSouth"; focus_south.text = "聚焦南方治理区"; focus_south.pressed.connect(_focus_south); gov_box.add_child(focus_south); _labels["FocusSouth"] = focus_south
	var mode_row := HBoxContainer.new(); gov_box.add_child(mode_row)
	for spec in [["faction", "阵营"], ["support", "民心"], ["insurgency", "叛乱"]]:
		var mode_button := Button.new(); mode_button.name = "Mode_" + spec[0]; mode_button.text = spec[1]; mode_button.pressed.connect(func(m=spec[0]): map_mode = m; _refresh_ui(); _map_layer.queue_redraw()); mode_row.add_child(mode_button)
	gov_box.add_child(_label("ActionTitle", "治理行动", 14, Color("f4d47d")))
	var action_row := HBoxContainer.new(); action_row.name = "ActionRow"; gov_box.add_child(action_row)
	for spec in [["support", "改善民生"], ["security", "恢复治安"], ["politics", "地方协商"]]:
		var action_button := Button.new(); action_button.name = "Action_" + spec[0]; action_button.text = spec[1]; action_button.tooltip_text = "选择地区后执行"; action_button.pressed.connect(func(k=spec[0]): _action(k)); action_row.add_child(action_button); _labels["Action_" + spec[0]] = action_button
	gov_box.add_child(_label("ActionCost", "行动消耗：民生 8预算/4政治 · 治安 10预算/4政治 · 谈判 6预算/8政治", 11, Color("a9b9bd")))
	coup_box.add_child(_label("CoupStatus", "政变战局 · 全国部队（平时可调动政府部队）", 11, Color("c9b7b0")))
	var coup_button := Button.new(); coup_button.name = "CoupButton"; coup_button.text = "模拟政变（锁定全国部队）"; coup_button.pressed.connect(_trigger_coup); coup_box.add_child(coup_button); _labels["CoupButton"] = coup_button
	var capital_button := Button.new(); capital_button.name = "CapitalCrisis"; capital_button.text = "进入首都危机（城市回合）"; capital_button.pressed.connect(_enter_capital_crisis); coup_box.add_child(capital_button); _labels["CapitalCrisis"] = capital_button
	var unit_select := OptionButton.new(); unit_select.name = "UnitSelect"; unit_select.text = "选择一支部队"
	for unit in units: unit_select.add_item("%s · %s" % [unit.name, _side_name(unit.side)], unit.id)
	unit_select.item_selected.connect(func(index: int): _select_unit(unit_select.get_item_id(index)))
	coup_box.add_child(unit_select); _labels["UnitSelect"] = unit_select
	var destination_row := HBoxContainer.new(); coup_box.add_child(destination_row)
	for i in 3:
		var destination := Button.new(); destination.name = "CoupDest%d" % i; destination.text = "调往%s" % coup_key_names[i]; destination.pressed.connect(func(key_index=i): _move_selected_to_key(key_index)); destination_row.add_child(destination); _labels["CoupDest%d" % i] = destination
	coup_box.add_child(_label("CoupFeedback", "政变页反馈：先选择政府部队", 11, Color("f4d47d")))
	var selection_panel := PanelContainer.new(); selection_panel.name = "SelectionPanel"; selection_panel.add_theme_stylebox_override("panel", _style_panel(Color("18282d"), 6)); gov_box.add_child(selection_panel)
	var selection_box := VBoxContainer.new(); selection_box.add_theme_constant_override("separation", 3); selection_panel.add_child(selection_box)
	selection_box.add_child(_label("SelectionTitle", "选区详情", 14, Color("f4d47d")))
	selection_box.add_child(_label("Selection", "尚未选择地区", 13, Color("edf4f3")))
	selection_box.add_child(_label("SelectionStats", "点击地图上的地区查看治理指标", 12, Color("b9c9cc")))
	var event_panel := PanelContainer.new(); event_panel.name = "EventPanel"; event_panel.add_theme_stylebox_override("panel", _style_panel(Color("2a2220"), 6)); gov_box.add_child(event_panel)
	var event_box := VBoxContainer.new(); event_box.add_theme_constant_override("separation", 4); event_panel.add_child(event_box)
	event_box.add_child(_label("Event", "事件：尚未发生（每28天检查）", 13, Color("f2c77b")))
	var event_row := HBoxContainer.new(); event_box.add_child(event_row)
	var accept := Button.new(); accept.name = "EventA"; accept.text = "方案一"; accept.visible = false; accept.pressed.connect(func(): _resolve_event(0)); event_row.add_child(accept); _labels["EventA"] = accept
	var decline := Button.new(); decline.name = "EventB"; decline.text = "方案二"; decline.visible = false; decline.pressed.connect(func(): _resolve_event(1)); event_row.add_child(decline); _labels["EventB"] = decline
	gov_box.add_child(_label("Feedback", feedback, 12, Color("f4d47d")))
	var reset_view := Button.new(); reset_view.name = "ResetView"; reset_view.text = "重置地图视图"; reset_view.pressed.connect(_reset_view); gov_box.add_child(reset_view)
	var restart := Button.new(); restart.name = "Restart"; restart.text = "重新开始模拟"; restart.visible = false; restart.pressed.connect(_restart); gov_box.add_child(restart); _labels["Restart"] = restart
	_apply_button_theme(box)

func _apply_button_theme(parent: Node) -> void:
	for child in parent.get_children():
		if child is Button:
			var normal := _style_panel(Color("1b2b31"), 5); normal.content_margin_top = 6; normal.content_margin_bottom = 6
			var hover := _style_panel(Color("2b4d50"), 5); hover.content_margin_top = 6; hover.content_margin_bottom = 6
			var pressed := _style_panel(Color("396b62"), 5); pressed.content_margin_top = 6; pressed.content_margin_bottom = 6
			var disabled := _style_panel(Color("1a2022"), 5); disabled.content_margin_top = 6; disabled.content_margin_bottom = 6
			child.add_theme_stylebox_override("normal", normal); child.add_theme_stylebox_override("hover", hover); child.add_theme_stylebox_override("pressed", pressed); child.add_theme_stylebox_override("disabled", disabled)
			child.add_theme_color_override("font_color", Color("e7f0ee")); child.add_theme_color_override("font_hover_color", Color.WHITE); child.add_theme_font_size_override("font_size", 12)
		else: _apply_button_theme(child)

func _toggle_pause() -> void:
	if ended: return
	if active_event != "":
		paused = true; feedback = "请先处理待决事件，再继续模拟"; _refresh_ui(); queue_redraw(); return
	paused = not paused; feedback = "模拟已暂停" if paused else "模拟继续推进"; _refresh_ui(); queue_redraw()

func _reset_view() -> void:
	zoom = 1.0; offset = Vector2.ZERO; _sync_map_transform(); _map_layer.queue_redraw(); _refresh_ui()

func _focus_south() -> void:
	zoom = 1.3; offset = Vector2(0, -190); _clamp_view(); _sync_map_transform(); _map_layer.queue_redraw(); feedback = "已聚焦南方治理区"; _refresh_ui()

func _side_name(side: String) -> String:
	return {"government": "反政变方", "coup": "政变方", "neutral": "中立"}.get(side, side)

func _coup_key_display() -> String:
	var names: Array[String] = []
	for i in coup_key_regions.size(): names.append("%s(%s)" % [coup_key_names[i], regions[coup_key_regions[i]].name])
	return " / ".join(names)

func _select_unit(unit_id: int) -> void:
	if ended: return
	for unit in units:
		if unit.id == unit_id:
			if unit.side != player_side:
				selected_unit = -1; feedback = "%s由%s控制，玩家不能越权调动" % [unit.name, _side_name(unit.side)]
			else:
				selected_unit = unit_id; feedback = "已选%s：点击地图上的目的地区" % unit.name
			_refresh_ui(); _map_layer.queue_redraw(); return

func _move_unit_to_region(unit_id: int, destination: int, actor := "player") -> bool:
	if ended or destination < 0 or destination >= regions.size(): return false
	if _capital_crisis != null and _capital_crisis.visible:
		for city_unit in _capital_crisis.city_positions:
			if int(city_unit) == unit_id:
				feedback = "首都危机进行中：首都部队只能使用城市行动命令"; _refresh_ui(); return false
	var unit_index := -1
	for i in units.size():
		if units[i].id == unit_id: unit_index = i; break
	if unit_index < 0: return false
	var unit: Dictionary = units[unit_index]
	if actor == "player" and unit.side != "government":
		feedback = "%s由%s控制，玩家不能越权调动" % [unit.name, _side_name(unit.side)]; _refresh_ui(); return false
	if actor == "ai" and unit.side != "coup": return false
	if actor != "player" and actor != "ai": return false
	if coup_state == "active" and unit.side == "neutral":
		feedback = "政变期间全国部队冻结：中立部队不可调动"; _refresh_ui(); return false
	if coup_state == "active" and unit.side == "coup" and actor != "ai":
		feedback = "政变部队由简单AI调集，玩家只能调动反政变方"; _refresh_ui(); return false
	units[unit_index].region = destination
	if actor == "player": feedback = "%s已调往%s" % [unit.name, regions[destination].name]
	_map_layer.queue_redraw(); _refresh_ui(); return true

func _move_selected_to_key(key_index: int) -> void:
	if selected_unit < 0 or key_index < 0 or key_index >= coup_key_regions.size():
		feedback = "先在政变页选择一支政府部队"; _refresh_ui(); return
	_move_unit_to_region(selected_unit, coup_key_regions[key_index])

func _trigger_coup() -> void:
	if ended or coup_state == "active": return
	if active_event != "": feedback = "请先处理当前事件"; _refresh_ui(); return
	coup_state = "active"; coup_turns = 0; coup_progress = {"government": 0, "coup": 0}; paused = true; selected_unit = -1; feedback = "政变开始：全国部队冻结；只能调动反政变方，政变方由AI行动，中立部队不可动"; _refresh_ui(); _map_layer.queue_redraw(); queue_redraw()

func _enter_capital_crisis() -> void:
	if ended: return
	if coup_state != "active": feedback = "请先点击模拟政变，再进入首都危机"; _refresh_ui(); return
	if _capital_crisis == null:
		_capital_layer = CanvasLayer.new(); _capital_layer.name = "CapitalCrisisLayer"; _capital_layer.layer = 50; add_child(_capital_layer)
		_capital_crisis = load("res://scripts/capital_crisis.gd").new(); _capital_layer.add_child(_capital_crisis); _capital_crisis.setup(self)
	_capital_crisis.visible = true; paused = true; _capital_crisis.queue_redraw()

func _coup_weekly() -> void:
	if coup_state != "active" or ended: return
	coup_turns += 1
	# Three southern control points make troop movement matter: capital, radio,
	# and barracks. The coup AI captures the weakest point through the same move
	# permission path available to the player.
	var target: int = coup_key_regions[0] if not coup_key_regions.is_empty() else 0
	for unit in units:
		if unit.side == "coup": _move_unit_to_region(unit.id, target, "ai")
	var government_power := 0; var coup_power := 0
	for unit in units:
		if not coup_key_regions.has(unit.region): continue
		if unit.side == "government": government_power += int(unit.strength)
		elif unit.side == "coup": coup_power += int(unit.strength)
	coup_progress["government"] = clampi(int(coup_progress["government"]) + int(ceil(float(government_power) / 4.0)), 0, 100)
	coup_progress["coup"] = clampi(int(coup_progress["coup"]) + int(ceil(float(coup_power) / 4.0)), 0, 100)
	if coup_progress["government"] >= 100: _resolve_coup("government")
	elif coup_progress["coup"] >= 100: _resolve_coup("coup")

func _resolve_coup(winner: String) -> void:
	if winner == "government":
		coup_state = "resolved"; paused = true
		for unit in units:
			if unit.side == "coup" or unit.side == "neutral": unit.side = "government"
		feedback = "反政变方获胜：军队解冻，所有部队恢复政府调度"
	else:
		coup_state = "lost"; _end_game("政变方夺权：反政变部队未能控制全国")
	_refresh_ui(); _map_layer.queue_redraw(); queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("101820")); draw_rect(Rect2(12, 76, 874, 684), Color("1c2b31")); draw_rect(Rect2(0, 0, 1280, 68), Color("0b1115"))
	draw_string(ThemeDB.fallback_font, Vector2(22, 29), "越南战争 · 大战略原型", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(22, 53), "1965 年开局　南方执政与地区治理（设计区域抽象）", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7c47a"))
	draw_string(ThemeDB.fallback_font, Vector2(430, 31), "%04d 年 %02d 月 %02d 日" % [simulation.year, simulation.month, simulation.day], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e8edf0"))
	draw_string(ThemeDB.fallback_font, Vector2(430, 55), "状态：" + ("结束 · " + outcome if ended else ("暂停" if paused else "运行")) + "　速度：" + str(speed) + "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b8c6ca"))
	draw_rect(Rect2(20, 752, 858, 1), Color("3b5458")); draw_string(ThemeDB.fallback_font, Vector2(20, 793), "左键选择地区　空格暂停　1/2/4倍速　滚轮缩放　中键拖动　F阵营 H民心 I叛乱", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b8c6ca"))

func _region_at(pos: Vector2) -> int:
	if not MAP_RECT.has_point(pos): return -1
	for i in regions.size():
		for ring in regions[i].rings:
			var poly := PackedVector2Array()
			for point in ring: poly.append(_point(float(point[0]), float(point[1])))
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(pos, poly): return i
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and MAP_RECT.has_point(event.position):
			var hit := _region_at(event.position)
			if selected_unit >= 0 and hit >= 0: _move_unit_to_region(selected_unit, hit)
			selected = hit; feedback = "已选择地区，可执行治理行动" if selected >= 0 else "这里没有可治理的地区"; _refresh_ui(); queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE: dragging = event.pressed
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and MAP_RECT.grow(20).has_point(event.position):
			var anchor := _unproject(event.position); zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.87), 1.0, 3.0)
			var scale := minf(MAP_RECT.size.x / (LON_MAX - LON_MIN), MAP_RECT.size.y / (LAT_MAX - LAT_MIN)); offset = event.position - (MAP_RECT.get_center() - Vector2((LON_MAX - LON_MIN) * scale, (LAT_MAX - LAT_MIN) * scale) * zoom * 0.5 + Vector2(anchor.x, anchor.y) * scale * zoom); _clamp_view(); _sync_map_transform(); queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		offset += event.relative; _clamp_view(); _sync_map_transform(); queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE: _toggle_pause()
		elif event.keycode == KEY_1: speed = 1.0
		elif event.keycode == KEY_2: speed = 2.0
		elif event.keycode == KEY_4: speed = 4.0
		elif event.keycode == KEY_F: map_mode = "faction"; _map_layer.queue_redraw()
		elif event.keycode == KEY_H: map_mode = "support"; _map_layer.queue_redraw()
		elif event.keycode == KEY_I: map_mode = "insurgency"; _map_layer.queue_redraw()
		elif event.keycode == KEY_M: _action("support")
		elif event.keycode == KEY_S: _action("security")
		elif event.keycode == KEY_P: _action("politics")
		elif event.keycode == KEY_ESCAPE: get_tree().quit()
		_refresh_ui(); queue_redraw()

func _process(delta: float) -> void:
	if paused or ended: return
	elapsed += delta * speed; var days := int(elapsed / 0.5)
	if days <= 0: return
	elapsed -= float(days) * 0.5; _advance_simulation_days(days); _refresh_ui(); queue_redraw()

func _advance_simulation_days(days: int) -> void:
	for _i in range(days):
		if paused or ended: return
		total_days += 1; simulation.advance_days(1)
		if total_days % 7 == 0: _weekly_settlement()
		if ended: return
		if total_days % 28 == 0 and active_event == "": _start_event()
		if active_event != "": paused = true; return

func _action(kind: String) -> void:
	if ended: feedback = "模拟已结束，请点击重新开始模拟"; _refresh_ui(); return
	if not ACTION_COSTS.has(kind): return
	if selected < 0: feedback = "请先选择一个南方地区"; _refresh_ui(); return
	var r: Dictionary = regions[selected]
	if r.faction != "south": feedback = "北方地区属于外部压力，不能直接治理"; _refresh_ui(); return
	if kind == "politics" and talk_cooldown > 0: feedback = "地方协商冷却中，还需 %d 周" % talk_cooldown; _refresh_ui(); return
	var cost: Dictionary = ACTION_COSTS[kind]
	if budget < int(cost.budget) or political_capital < int(cost.politics): feedback = "资源不足：需要预算 %d、政治资本 %d" % [cost.budget, cost.politics]; _refresh_ui(); return
	budget -= int(cost.budget); political_capital -= int(cost.politics)
	if kind == "support":
		r.support = clampi(int(r.support) + 10, 0, 100); r.insurgency = maxi(0, int(r.insurgency) - 4); feedback = "民生项目完成：民心改善，预算 -8、政治资本 -4"
	elif kind == "security":
		r.security = clampi(int(r.security) + 12, 0, 100); r.insurgency = maxi(0, int(r.insurgency) - 6); feedback = "治安行动完成：安全改善，预算 -10、政治资本 -4"
	else:
		faction_support["地方官僚"] = mini(100, int(faction_support["地方官僚"]) + 5); faction_support["民间力量"] = maxi(0, int(faction_support["民间力量"] ) - 3); talk_cooldown = 3; feedback = "地方协商完成：官僚支持上升，民间力量略降；3周后可再次协商"
	_refresh_ui(); _map_layer.queue_redraw(); queue_redraw()

func _weekly_settlement() -> void:
	if ended: return
	budget = mini(150, budget + 12); political_capital = mini(100, political_capital + 3); talk_cooldown = maxi(0, talk_cooldown - 1)
	for r in regions:
		if r.faction == "south": r.insurgency = clampi(int(r.insurgency) + (1 if int(r.security) < 40 else -1), 0, 100)
	var support_sum := 0.0; var security_sum := 0.0; var insurgency_sum := 0.0; var south_count := 0
	for r in regions:
		if r.faction == "south": south_count += 1; support_sum += float(r.support); security_sum += float(r.security); insurgency_sum += float(r.insurgency)
	var region_score := 50.0
	if south_count > 0: region_score = (support_sum / south_count + security_sum / south_count + 100.0 - insurgency_sum / south_count) / 3.0
	var faction_score := (int(faction_support["军方"]) + int(faction_support["地方官僚"]) + int(faction_support["民间力量"])) / 3.0
	stability = clampi(roundi(faction_score * 0.7 + region_score * 0.3), 0, 100); feedback = "周结算：预算 +12、政治资本 +3；稳定度 %d" % stability
	if coup_state == "active": _coup_weekly()
	if ended: _refresh_ui(); return
	if int(faction_support["军方"]) < 15: _end_game("政权倒台：军方支持跌破底线")
	elif stability < 25: _end_game("政权倒台：三派支持与南方治理指标过低")
	elif total_days >= 140 and stability >= 45: _end_game("阶段成功：南方政权维持了二十周")
	_refresh_ui(); _map_layer.queue_redraw(); queue_redraw()

func _start_event() -> void:
	if ended or active_event != "": return
	active_event_data = EVENT_DEFS[event_index % EVENT_DEFS.size()].duplicate(true); event_index += 1; active_event = active_event_data.title; feedback = "新事件待决：请比较两种方案的资源成本与派系影响"; _refresh_ui(); queue_redraw()

func _resolve_event(choice: int) -> void:
	if ended or active_event == "" or active_event_data.is_empty(): return
	var option: Dictionary = active_event_data["a" if choice == 0 else "b"]
	if budget < int(option.budget) or political_capital < int(option.politics): feedback = "资源不足，事件仍待决：需要预算 %d、政治资本 %d" % [option.budget, option.politics]; _refresh_ui(); return
	budget -= int(option.budget); political_capital -= int(option.politics); faction_support[option.faction] = clampi(int(faction_support[option.faction]) + int(option.delta), 0, 100); faction_support[option.other] = clampi(int(faction_support[option.other]) + int(option.other_delta), 0, 100)
	feedback = "事件已处理：%s；%s %+d，%s %+d" % [option.label, option.faction, option.delta, option.other, option.other_delta]; active_event = ""; active_event_data = {}; paused = false; _refresh_ui(); queue_redraw()

func _end_game(result: String) -> void:
	ended = true; outcome = result; paused = true; active_event = ""; active_event_data = {}; feedback = result

func _restart() -> void:
	regions = _initial_regions.duplicate(true); selected = 0; paused = true; speed = 1.0; elapsed = 0.0; simulation = Simulation.new(); budget = 100; political_capital = 60; faction_support = {"军方": 58, "地方官僚": 52, "民间力量": 46}; stability = 62; talk_cooldown = 0; total_days = 0; event_index = 0; active_event = ""; active_event_data = {}; ended = false; outcome = ""; coup_state = "stable"; coup_turns = 0; coup_progress = {"government": 0, "coup": 0}; selected_unit = -1; _find_coup_key_regions(); _init_units(); feedback = "已重新开始：建议先改善民生，再恢复治安"; _refresh_ui(); _map_layer.queue_redraw(); queue_redraw()

func _refresh_ui() -> void:
	if _labels.is_empty(): return
	_labels["Resources"].text = "资源　预算 %d　·　政治资本 %d" % [budget, political_capital]
	_labels["Factions"].text = "派系支持　军方 %d　地方官僚 %d　民间力量 %d" % [faction_support["军方"], faction_support["地方官僚"], faction_support["民间力量"]]
	_labels["Status"].text = "稳定度 %d　·　%s" % [stability, "已结束" if ended else ("暂停" if paused else "推进中")]
	_labels["Feedback"].text = "反馈：" + feedback
	_labels["CoupFeedback"].text = "政变页反馈：" + feedback
	_labels["CoupStatus"].text = "政变战局 · 控制点：" + _coup_key_display() if coup_state == "stable" else ("政变进度　反政变方 %d%%　政变方 %d%%　·　第%d周　控制点：%s" % [coup_progress["government"], coup_progress["coup"], coup_turns, _coup_key_display()] if coup_state == "active" else "政变已平息：全国部队解冻")
	var pause_button: Button = _labels["PauseButton"]
	pause_button.text = "已结束" if ended else ("继续模拟" if paused else "暂停模拟")
	_labels["Selection"].text = "尚未选择地区"; _labels["SelectionStats"].text = "点击地图上的地区查看治理指标"
	if selected >= 0 and selected < regions.size():
		var r: Dictionary = regions[selected]; _labels["Selection"].text = "%s　·　%s" % [r.name, "北方外压" if r.faction == "north" else "南方可治理"]; _labels["SelectionStats"].text = "地形 %s　民心 %d　治安 %d　叛乱 %d" % [_terrain_name(r.terrain), r.support, r.security, r.insurgency]
	var event_label: Label = _labels["Event"]; var a: Button = _labels["EventA"]; var b: Button = _labels["EventB"]
	if active_event != "": event_label.text = "事件：" + active_event; a.visible = true; b.visible = true; a.text = active_event_data.a.label; b.text = active_event_data.b.label
	else: event_label.text = "事件：暂无待决事件（每28天检查）" if not ended else "事件：模拟已结束"; a.visible = false; b.visible = false
	var restart: Button = _labels["Restart"]; restart.visible = ended
	for kind in ["support", "security", "politics"]:
		var action_button: Button = _labels["Action_" + kind]
		action_button.disabled = ended
		if ended: action_button.tooltip_text = "模拟已结束"
		elif selected < 0: action_button.tooltip_text = "先选择南方地区"
		elif regions[selected].faction != "south": action_button.tooltip_text = "北方外压地区不可治理"
		elif kind == "politics" and talk_cooldown > 0: action_button.tooltip_text = "地方协商冷却中，还需 %d 周" % talk_cooldown
		else: action_button.tooltip_text = "执行%s：预算 -%d、政治资本 -%d" % [ACTION_COSTS[kind].label, ACTION_COSTS[kind].budget, ACTION_COSTS[kind].politics]
	var coup_button: Button = _labels["CoupButton"]; coup_button.disabled = ended or coup_state == "active" or coup_state == "resolved"; coup_button.tooltip_text = "演示政变：全国部队先冻结，反政变方可调动" if coup_state == "stable" else "政变战局已启动或结束"
	var capital_button: Button = _labels["CapitalCrisis"]; capital_button.disabled = ended or coup_state != "active"; capital_button.tooltip_text = "先模拟政变，再进入西贡首都回合" if coup_state != "active" else "进入城市回合，国家时间暂停"
	var unit_select: OptionButton = _labels["UnitSelect"]; unit_select.disabled = ended
	for i in units.size(): unit_select.set_item_text(i, "%s · %s" % [units[i].name, _side_name(units[i].side)])
	for i in 3:
		var destination: Button = _labels["CoupDest%d" % i]; destination.disabled = ended or selected_unit < 0; destination.tooltip_text = "将已选反政变部队调往%s" % coup_key_names[i]

func _terrain_name(terrain: String) -> String:
	return {"highland": "高地", "delta": "三角洲", "coastal": "沿海"}.get(terrain, "平原")
