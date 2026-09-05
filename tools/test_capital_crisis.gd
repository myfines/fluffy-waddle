extends SceneTree

var failures := 0
func check(v: bool, s: String) -> void:
	if not v: failures += 1; push_error("FAIL: " + s)

func _init() -> void: call_deferred("run")

func run() -> void:
	var national: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(national); await process_frame
	national._trigger_coup(); national._enter_capital_crisis(); await process_frame
	var city = national._capital_crisis
	check(city.visible and city.CITY_NODES.size() == 9, "首都危机覆盖层打开并加载9个原创城区")
	check(city.ROADS.size() >= 10 and city._node_neighbors(0).has(1), "道路邻接可查询")
	var gov_region: int = national.units[0].region; var coup_initial: int = city.city_positions[5]; check(not national._move_unit_to_region(0, 1), "城市回合拒绝全国绕过调动"); check(national.units[0].region == gov_region, "全国单位状态不被城市绕过改变")
	city.current_side = "coup"; city.selected_node = 4; check(city._city_action("move", "ai"), "AI将政变部队调入中立市政厅")
	city.current_side = "government"; city._select_unit(2); city.selected_node = 4; var defended_ap: int = city.ap; check(not city._city_action("control") and city.ap == defended_ap and city.node_owner[4] == "neutral", "敌军驻守中立点时兵力防御生效")
	city._select_unit(0); city.selected_node = 1; var before_ap: int = city.ap; check(city._city_action("move"), "相邻城区移动成功"); check(city.ap == before_ap - 1, "移动消耗1AP")
	var illegal_ap: int = city.ap; city.selected_node = 8; check(not city._city_action("move") and city.ap == illegal_ap, "非相邻目标拒绝且不扣AP")
	city.selected_node = 1; check(city._city_action("control"), "控制警察局成功"); check(city.node_owner[1] == "government" and city.node_order[1] > 0, "警察局控制产生秩序收益"); var authority_before: int = city.authority["government"]; var repeat_ap: int = city.ap; check(not city._city_action("control") and city.ap == repeat_ap and city.authority["government"] == authority_before, "重复控制不会刷收益或扣AP")
	if city.ap == 0: city._end_turn()
	while city.ap > 0: city.selected_node = 1; city._city_action("rally")
	check(city.ap == 0 and not city._city_action("rally") and city.node_order[1] > 50, "整顿行动有确定性秩序收益且AP不负")
	var unknown_ap: int = city.ap; check(not city._city_action("unknown") and city.ap == unknown_ap, "未知城市行动拒绝")
	var round_before: int = city.round; city._end_turn(); check(city.round == round_before + 1 and city.ap == 3 and city.current_side == "government", "结束回合触发AI并刷新AP"); check(city.city_positions[5] != coup_initial, "政变AI通过统一城市移动命令改变位置")
	var saved_round: int = city.round; var saved_total: int = national.total_days; var saved_national_region: int = national.units[0].region; city._close(); check(not city.visible and national.paused, "返回全国且国家时间暂停"); national._toggle_pause(); national._advance_simulation_days(7); national._weekly_settlement(); check(national.total_days == saved_total and national.units[0].region == saved_national_region and national.paused, "城市实例存在时切屏不解锁全国时间/军令")
	national._enter_capital_crisis(); await process_frame; check(city.visible and city.round == saved_round and city.ap == 3, "重新进入保持城市状态")
	# Complete a real government win in a fresh crisis with legal commands, no
	# forced AP or owner values: units 3 and 2 guard two neutral points.
	var national2: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(national2); await process_frame; national2._trigger_coup(); national2._enter_capital_crisis(); await process_frame
	var city2 = national2._capital_crisis; city2._select_unit(3); city2.selected_node = 7; check(city2._city_action("control"), "合法控制河岸公园")
	city2._select_unit(2); city2.selected_node = 4; check(city2._city_action("control"), "合法控制市政厅")
	city2._select_unit(0); city2.selected_node = 1; check(city2._city_action("move"), "城市移动使用公开AP"); check(city2.ap == 0, "三次行动恰好消耗3AP")
	city2._end_turn(); city2._select_unit(0); city2.selected_node = 1; check(city2._city_action("control"), "第二回合攻占警察局"); check(city2.city_outcome != "", "真实城市回合形成胜负结局")
	check(national2.coup_state == "resolved" or national2.ended, "城市结局写回全国政变状态")
	var national3: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(national3); await process_frame; national3._trigger_coup(); national3._enter_capital_crisis(); await process_frame
	var city3 = national3._capital_crisis
	for _turn in range(10):
		if city3.city_outcome != "": break
		city3._end_turn()
	check(city3.city_outcome != "" and national3.ended, "不调兵时AI通过真实回合赢得城市并结束全国局")
	print("capital-crisis-tests: PASS" if failures == 0 else "capital-crisis-tests: FAIL count=" + str(failures)); quit(0 if failures == 0 else 1)
