extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; return event

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var s: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(s); await process_frame
	check(s.regions.size() == 710, "加载全部710个设计区域")
	check(s.selected == 0 and s.units.size() == 10, "开局默认南方选区并加载10支全国部队")
	var north := 0
	for r in s.regions:
		if float(r.lat) >= 17.0: check(r.faction == "north", "17度以北归为北方外压"); north += 1
		else: check(r.faction == "south", "17度以南归为南方可治理")
	check(north > 0 and north < s.regions.size(), "南北分类存在且边界可辨")
	s.selected = 0; s.budget = 100; s.political_capital = 60
	s._action("support"); check(s.budget == 92 and s.political_capital == 56, "民生统一消耗8预算4政治")
	s.budget = 100; s.political_capital = 60; s._unhandled_input(key(KEY_M)); check(s.budget == 92 and s.political_capital == 56, "M快捷键与民生按钮使用同一成本")
	s.budget = 100; s.political_capital = 60; s._labels["Action_security"].emit_signal("pressed"); check(s.budget == 90 and s.political_capital == 56, "治安按钮使用10预算4政治")
	s.budget = 100; s.political_capital = 60; s._unhandled_input(key(KEY_S)); check(s.budget == 90 and s.political_capital == 56, "S快捷键与治安按钮使用同一成本")
	s.budget = 100; s.political_capital = 60; s._action("politics"); check(s.budget == 94 and s.political_capital == 52 and s.talk_cooldown == 3, "谈判统一消耗6预算8政治并进入3周冷却")
	var before_budget: int = s.budget; s._unhandled_input(key(KEY_P)); check(s.budget == before_budget and s.feedback.contains("冷却"), "谈判冷却阻止快捷键重复执行")
	var north_index := -1
	for i in s.regions.size():
		if s.regions[i].faction == "north": north_index = i; break
	s.selected = north_index; s._action("support"); check(s.feedback.contains("外部压力"), "北方区域不可治理")
	s.selected = 0
	# Coup permissions are enforced in the shared move command, including AI.
	s._trigger_coup(); check(s.coup_state == "active" and s.paused, "政变触发并冻结模拟")
	var neutral_region: int = s.units[8].region; check(not s._move_unit_to_region(8, 0), "政变期间中立部队不可调动"); check(s.units[8].region == neutral_region, "中立部队位置保持冻结")
	check(not s._move_unit_to_region(5, 0), "玩家不可越权调动政变方"); check(s._move_unit_to_region(0, 1), "反政变方部队可调动")
	s.coup_progress["government"] = 99; s._weekly_settlement(); check(s.coup_state == "resolved" and not s.ended, "反政变方胜利解锁全国部队")
	for unit in s.units: check(unit.side == "government", "反政变胜利后部队恢复政府调度")
	# Reset before event cadence assertions.
	s._restart()
	# Every event exposes two real choices; insufficient resources leave it pending.
	for choice in [0, 1, 0, 1, 0, 1]:
		s._start_event(); check(s.active_event != "" and s._labels["EventA"].visible and s._labels["EventB"].visible, "事件显示双选按钮")
		s.budget = 0; s.political_capital = 0; s._resolve_event(choice); check(s.active_event != "" and s.feedback.contains("资源不足"), "资源不足不会偷偷视为拒绝")
		s.budget = 150; s.political_capital = 100; s._resolve_event(choice); check(s.active_event == "" and not s._labels["EventA"].visible, "事件选择后结算并隐藏按钮")
	# Daily advancement reaches the first scheduled event exactly at day 28.
	s.paused = false; s.total_days = 0; s._advance_simulation_days(28); check(s.total_days == 28 and s.active_event != "" and s.paused, "28天逐日推进并暂停等待真实事件")
	var event_day: int = s.total_days; s._toggle_pause(); check(s.total_days == event_day and s.paused and s.feedback.contains("待决事件"), "待决事件不能通过暂停按钮偷走一天")
	s._advance_simulation_days(7); check(s.total_days == event_day, "待决事件不会覆盖或继续推进")
	s.budget = 150; s.political_capital = 100; s._resolve_event(0); s.paused = false; s._advance_simulation_days(35); check(s.total_days >= 56 and s.active_event != "", "跨多周推进到下一次事件")
	# Failure freezes all controls; success is a separate fresh run.
	s._end_game("测试倒台"); var frozen_budget: int = s.budget; s._action("support"); s._unhandled_input(key(KEY_M)); check(s.budget == frozen_budget and s.paused and s.ended, "结束后行动与快捷键均无效")
	s._restart(); s.faction_support["军方"] = 14; s._weekly_settlement(); check(s.ended and s.outcome.contains("军方"), "军方支持过低导致倒台")
	s._labels["Restart"].emit_signal("pressed"); check(not s.ended and s.budget == 100 and s.total_days == 0, "重新开始恢复模拟")
	var s2: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(s2); await process_frame
	s2.total_days = 140; s2.faction_support = {"军方": 100, "地方官僚": 100, "民间力量": 100}; s2._weekly_settlement(); check(s2.ended and s2.outcome.contains("成功"), "20周且稳定度达标进入成功结束")
	var s3: Node2D = load("res://scenes/main.tscn").instantiate(); root.add_child(s3); await process_frame
	s3._trigger_coup(); s3.coup_progress["coup"] = 99; s3._weekly_settlement(); check(s3.ended and s3.outcome.contains("政变方"), "政变方胜利进入失败结束")
	# Selection UI is dynamic and reflects the clicked region.
	s.selected = 0; s._refresh_ui(); check(s._labels["Selection"].text.contains(str(s.regions[0].name)), "选区详情内容随选择刷新")
	print("governance-tests: PASS" if failures == 0 else "governance-tests: FAIL count=" + str(failures)); quit(0 if failures == 0 else 1)
