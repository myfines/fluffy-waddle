extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
func _init() -> void:
	var s = Simulation.new()
	s.advance_days(31)
	assert(s.year == 1965 and s.month == 2 and s.day == 1)
	s.year = 1964; s.month = 2; s.day = 28; s.advance_days(1)
	assert(s.day == 29)
	s.advance_days(1); assert(s.month == 3 and s.day == 1)
	s.year = 1965; s.month = 12; s.day = 31; s.advance_days(1)
	assert(s.year == 1966 and s.month == 1 and s.day == 1)
	print("simulation-tests: PASS")
	quit()
