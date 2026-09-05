extends Control

var host: Node
var current_side := "government"
var round := 1
var ap := 3
var selected_unit := -1
var selected_node := -1
var city_outcome := ""
var report := "反政变方先手：选择部队和相邻城区"
var node_owner := {}
var node_order := {}
var authority := {"government": 0, "coup": 0}
var city_positions := {}
var _buttons: Dictionary = {}
var _unit_select: OptionButton
var _return_button: Button

const CITY_NODES := [
	{"id": "presidential", "name": "总统府", "kind": "权威", "pos": Vector2(180, 220)},
	{"id": "police", "name": "警察局", "kind": "秩序", "pos": Vector2(390, 140)},
	{"id": "barracks", "name": "军营", "kind": "兵力", "pos": Vector2(650, 190)},
	{"id": "radio", "name": "电台", "kind": "广播", "pos": Vector2(720, 380)},
	{"id": "cityhall", "name": "市政厅", "kind": "行政", "pos": Vector2(470, 350)},
	{"id": "transport", "name": "交通枢纽", "kind": "机动", "pos": Vector2(260, 430)},
	{"id": "residential", "name": "居民区", "kind": "民心", "pos": Vector2(150, 590)},
	{"id": "river", "name": "河岸公园", "kind": "中立", "pos": Vector2(510, 570)},
	{"id": "university", "name": "大学区", "kind": "舆论", "pos": Vector2(780, 590)},
]
const ROADS := [[0, 1], [1, 2], [1, 4], [2, 3], [2, 4], [3, 4], [4, 5], [4, 7], [5, 6], [5, 7], [7, 8], [3, 8]]

func _ready() -> void:
	queue_redraw()

func setup(parent: Node) -> void:
	host = parent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in CITY_NODES.size(): node_owner[i] = "neutral"; node_order[i] = 0
	node_owner[0] = "government"; node_owner[5] = "government"; node_owner[2] = "coup"; node_owner[3] = "coup"
	for unit in host.units:
		if unit.id == 0: city_positions[unit.id] = 0
		elif unit.id == 1: city_positions[unit.id] = 5
		elif unit.id == 2: city_positions[unit.id] = 4
		elif unit.id == 5: city_positions[unit.id] = 2
		elif unit.id == 6: city_positions[unit.id] = 3
		elif unit.id == 7: city_positions[unit.id] = 1
		else: city_positions[unit.id] = 7
	_build_controls()
	call_deferred("queue_redraw")

func _style_button(color := Color("223842")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.corner_radius_top_left = 6; style.corner_radius_top_right = 6; style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6; style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1; style.border_color = Color("48636a"); style.content_margin_left = 10; style.content_margin_right = 10; style.content_margin_top = 6; style.content_margin_bottom = 6; return style

func _button(name: String, text: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
	var b := Button.new(); b.name = name; b.text = text; b.position = pos; b.size = size; b.pressed.connect(action); b.add_theme_stylebox_override("normal", _style_button()); b.add_theme_stylebox_override("hover", _style_button(Color("31535b"))); b.add_theme_stylebox_override("pressed", _style_button(Color("3f7168"))); b.add_theme_font_size_override("font_size", 13); add_child(b); _buttons[name] = b; return b

func _build_controls() -> void:
	_return_button = _button("Return", "返回全国大战略", Vector2(1050, 30), Vector2(200, 42), _close)
	_unit_select = OptionButton.new(); _unit_select.name = "CityUnitSelect"; _unit_select.position = Vector2(930, 235); _unit_select.size = Vector2(300, 42); _unit_select.text = "选择反政变方部队"; _unit_select.add_theme_stylebox_override("normal", _style_button()); _unit_select.add_theme_font_size_override("font_size", 13); add_child(_unit_select)
	for unit in host.units:
		if unit.side == "government": _unit_select.add_item("%s · 反政变方" % unit.name, unit.id)
	_unit_select.item_selected.connect(func(index: int): _select_unit(_unit_select.get_item_id(index)))
	_button("Move", "移动相邻城区 · 1 AP", Vector2(930, 300), Vector2(300, 40), func(): _city_action("move"))
	_button("Control", "控制地点 · 1 AP", Vector2(930, 350), Vector2(300, 40), func(): _city_action("control"))
	_button("Rally", "整顿秩序 · 1 AP", Vector2(930, 400), Vector2(300, 40), func(): _city_action("rally"))
	_button("Persuade", "争取中立 · 1 AP", Vector2(930, 450), Vector2(300, 40), func(): _city_action("persuade"))
	_button("EndTurn", "结束本方回合（0 AP也可）", Vector2(930, 520), Vector2(300, 46), _end_turn)
	var title := Label.new(); title.name = "CityTitle"; title.position = Vector2(930, 100); title.text = "首都危机 · 西贡抽象街区"; title.add_theme_font_size_override("font_size", 21); title.add_theme_color_override("font_color", Color("f3d27b")); add_child(title)

func _select_unit(unit_id: int) -> void:
	for unit in host.units:
		if unit.id == unit_id and unit.side == "government": selected_unit = unit_id; report = "已选%s：选择相邻城区" % unit.name; queue_redraw(); return
	report = "只能选择反政变方部队"; queue_redraw()

func _node_neighbors(index: int) -> Array:
	var result: Array = []
	for road in ROADS:
		if road[0] == index: result.append(road[1])
		elif road[1] == index: result.append(road[0])
	return result

func _unit_dict(unit_id: int) -> Dictionary:
	for unit in host.units:
		if unit.id == unit_id: return unit
	return {}

func _city_action(action: String, actor := "player") -> bool:
	if city_outcome != "": return false
	if not ["move", "control", "rally", "persuade"].has(action): report = "未知行动不可用"; queue_redraw(); return false
	if actor == "player" and current_side != "government": report = "当前不是反政变方回合"; queue_redraw(); return false
	if actor == "ai" and current_side != "coup": report = "AI只能在政变方回合行动"; queue_redraw(); return false
	if actor != "player" and actor != "ai": report = "未知执行者不可行动"; queue_redraw(); return false
	if ap <= 0: report = "本方 AP 已用尽，请结束回合"; queue_redraw(); return false
	var unit_id := selected_unit if actor == "player" else _ai_unit_for_action()
	if unit_id < 0: report = "先选择一支反政变方部队"; queue_redraw(); return false
	var unit := _unit_dict(unit_id)
	if unit.is_empty() or (actor == "player" and unit.side != "government") or (actor == "ai" and unit.side != "coup"): report = "部队归属不允许此行动"; queue_redraw(); return false
	var current: int = city_positions.get(unit_id, -1)
	if action == "move":
		if selected_node < 0 or not _node_neighbors(current).has(selected_node): report = "移动目标必须是相邻城区"; queue_redraw(); return false
		city_positions[unit_id] = selected_node; report = "%s移动到%s" % [unit.name, CITY_NODES[selected_node].name]
	elif action == "control":
		if selected_node < 0 or city_positions[unit_id] != selected_node: report = "控制地点需要部队先抵达该城区"; queue_redraw(); return false
		if node_owner[selected_node] == unit.side: report = "该地点已由本方控制，重复控制不会消耗AP"; queue_redraw(); return false
		if node_owner[selected_node] != unit.side:
			var defender_side: String = node_owner[selected_node]
			if defender_side == "neutral": defender_side = "coup" if unit.side == "government" else "government"
			var attacker := _power_at_node(selected_node, unit.side); var defender := _power_at_node(selected_node, defender_side) + int(node_order[selected_node] / 5)
			if defender > 0 and attacker < defender: report = "控制失败：守军兵力 %d 高于进攻兵力 %d" % [defender, attacker]; queue_redraw(); return false
		node_owner[selected_node] = unit.side; report = "%s控制了%s（%s）" % [unit.name, CITY_NODES[selected_node].name, CITY_NODES[selected_node].kind]
		_apply_node_benefit(selected_node, unit.side)
	elif action == "rally":
		if selected_node < 0 or city_positions[unit_id] != selected_node: report = "整顿目标必须是部队所在城区"; queue_redraw(); return false
		node_order[selected_node] = clampi(int(node_order[selected_node]) + (4 if CITY_NODES[selected_node].id == "police" else 2), 0, 100); report = "%s整顿%s：秩序提升至%d" % [unit.name, CITY_NODES[selected_node].name, node_order[selected_node]]
	else:
		if selected_node < 0 or city_positions[unit_id] != selected_node or node_owner[selected_node] != "neutral": report = "只能在部队所在的中立城区争取支持"; queue_redraw(); return false
		node_owner[selected_node] = unit.side; report = "%s争取了%s的中立力量" % [unit.name, CITY_NODES[selected_node].name]
	ap -= 1; _check_result(); queue_redraw(); return true

func _power_at_node(node_index: int, side: String) -> int:
	var result := 0
	for unit in host.units:
		if unit.side == side and city_positions.get(unit.id, -1) == node_index: result += int(unit.strength)
	return result

func _apply_node_benefit(node_index: int, side: String) -> void:
	var node_id: String = CITY_NODES[node_index].id
	if node_id == "police": node_order[node_index] = 50
	elif node_id == "barracks": authority[side] += 2
	elif node_id == "radio": authority[side] += 3
	elif node_id == "cityhall": authority[side] += 1
	elif node_id == "residential" or node_id == "university": authority[side] += 1

func _ai_unit_for_action() -> int:
	for unit in host.units:
		if unit.side == "coup": return unit.id
	return -1

func _end_turn() -> void:
	if city_outcome != "": return
	report = "政变方行动中……"; current_side = "coup"; ap = 3
	for _i in range(3):
		if _ai_unit_for_action() < 0: break
		var unit_id := _ai_unit_for_action(); var current: int = city_positions[unit_id]; var target: int = _node_neighbors(current)[0] if not _node_neighbors(current).is_empty() else current; selected_node = target; _city_action("move", "ai"); selected_node = target; _city_action("control", "ai")
	current_side = "government"; ap = 3; round += 1; selected_node = -1; report = "第%d回合：反政变方行动，请选择部队" % round; _check_result(); queue_redraw()

func _check_result() -> void:
	var gov := 0; var coup := 0
	for owner in node_owner.values():
		if owner == "government": gov += 1
		elif owner == "coup": coup += 1
	if gov >= 5 or int(authority["government"]) >= 6: _finish("government", "反政变方控制关键城区并建立权威，首都危机获胜")
	elif coup >= 5 or int(authority["coup"]) >= 6: _finish("coup", "政变方控制关键城区，首都危机失败")
	elif round > 8:
		_finish("government" if gov >= coup else "coup", "回合上限结算：反政变方 %d 点，政变方 %d 点" % [gov, coup])

func _finish(winner: String, text: String) -> void:
	city_outcome = text; report = text
	if winner == "government":
		host.coup_state = "resolved"; host.faction_support["军方"] = clampi(int(host.faction_support["军方"]) + 8, 0, 100); host.stability = clampi(int(host.stability) + 6, 0, 100)
		for unit in host.units:
			if unit.side == "coup" or unit.side == "neutral": unit.side = "government"
	else: host._end_game(text)
	host._refresh_ui(); queue_redraw()

func _close() -> void:
	visible = false; host.paused = true; host.feedback = "已返回全国视图：首都危机状态保留"; host._refresh_ui(); host.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.x < 900 and event.position.y > 80:
		var nearest := -1; var distance: float = 99999.0
		for i in CITY_NODES.size():
			var d: float = event.position.distance_squared_to(CITY_NODES[i].pos)
			if d < distance and d < 2300.0: nearest = i; distance = d
		if nearest >= 0: selected_node = nearest; report = "已选%s（%s）：" % [CITY_NODES[nearest].name, CITY_NODES[nearest].kind] + ("合法相邻目标" if selected_unit >= 0 and _node_neighbors(city_positions[selected_unit]).has(nearest) else "请选择部队所在或相邻城区"); queue_redraw(); get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color("0c151b")); draw_rect(Rect2(24, 78, 850, 690), Color("172a31")); draw_rect(Rect2(900, 78, 356, 690), Color("111d22"))
	# Original tabletop-like district map: roads, river and block shapes.
	draw_rect(Rect2(35, 100, 830, 640), Color("1b343b"), true)
	draw_rect(Rect2(80, 525, 760, 110), Color("18434b"), true)
	for road in ROADS: draw_line(CITY_NODES[road[0]].pos, CITY_NODES[road[1]].pos, Color("8d9b91"), 12.0, true); draw_line(CITY_NODES[road[0]].pos, CITY_NODES[road[1]].pos, Color("354b4f"), 6.0, true)
	for i in CITY_NODES.size():
		var n = CITY_NODES[i]; var owner_color := Color("4f9b7b") if node_owner[i] == "government" else Color("b6575d") if node_owner[i] == "coup" else Color("8e9894")
		draw_rect(Rect2(n.pos - Vector2(48, 26), Vector2(96, 52)), Color("24353a"), true); draw_rect(Rect2(n.pos - Vector2(48, 26), Vector2(96, 52)), owner_color, false, 3.0)
		draw_string(ThemeDB.fallback_font, n.pos + Vector2(-39, 4), n.name, HORIZONTAL_ALIGNMENT_LEFT, 84, 13, Color("f1eee1")); draw_string(ThemeDB.fallback_font, n.pos + Vector2(-35, 20), n.kind, HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color("b8c9c3"))
		if i == selected_node: draw_rect(Rect2(n.pos - Vector2(54, 32), Vector2(108, 64)), Color("f3d377"), false, 3.0)
	for unit in host.units:
		if not city_positions.has(unit.id): continue
		var stack := 0
		for other in host.units:
			if other.id != unit.id and city_positions.get(other.id, -1) == city_positions[unit.id] and other.id < unit.id: stack += 1
		var p: Vector2 = CITY_NODES[city_positions[unit.id]].pos + Vector2(-8 + stack * 20, -42)
		var c := Color("e2b957") if unit.side == "government" else Color("d45c63") if unit.side == "coup" else Color("a7b1ae")
		draw_rect(Rect2(p, Vector2(16, 16)), c, true); draw_string(ThemeDB.fallback_font, p + Vector2(3, 12), "G" if unit.side == "government" else "C" if unit.side == "coup" else "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("101820"))
	var gov_count := 0; var coup_count := 0
	for owner in node_owner.values():
		if owner == "government": gov_count += 1
		elif owner == "coup": coup_count += 1
	draw_string(ThemeDB.fallback_font, Vector2(930, 155), "桌游规则：每方3 AP · 玩家先手", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7c47a")); draw_string(ThemeDB.fallback_font, Vector2(930, 185), "第%d回合　当前：%s　AP：%d" % [round, "反政变方" if current_side == "government" else "政变方AI", ap], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE); draw_string(ThemeDB.fallback_font, Vector2(930, 215), "控制点 G/C：%d/%d　权威 G/C：%d/6 · %d/6" % [gov_count, coup_count, authority["government"], authority["coup"]], HORIZONTAL_ALIGNMENT_LEFT, 320, 12, Color("b9c9cc"))
	if selected_node >= 0: draw_string(ThemeDB.fallback_font, Vector2(930, 575), "选中：%s　归属：%s　兵力 G/C：%d/%d　秩序：%d\n效果：%s" % [CITY_NODES[selected_node].name, "反政变方" if node_owner[selected_node] == "government" else "政变方" if node_owner[selected_node] == "coup" else "中立", _power_at_node(selected_node, "government"), _power_at_node(selected_node, "coup"), node_order[selected_node], _node_effect(CITY_NODES[selected_node].id)], HORIZONTAL_ALIGNMENT_LEFT, 310, 11, Color("e6d18a"))
	draw_string(ThemeDB.fallback_font, Vector2(930, 640), "战报：" + report, HORIZONTAL_ALIGNMENT_LEFT, 300, 13, Color("f2c77b")); draw_string(ThemeDB.fallback_font, Vector2(930, 715), "绿色=反政变方　红色=政变方　灰色=中立\n点击街区查看合法目标", HORIZONTAL_ALIGNMENT_LEFT, 300, 12, Color("a9b9bd"))

func _node_effect(node_id: String) -> String:
	return {"police": "控制后秩序50，整顿额外+4", "barracks": "控制后权威+2", "radio": "控制后权威+3", "cityhall": "控制后权威+1", "residential": "控制后权威+1"}.get(node_id, "连接与占领收益")
