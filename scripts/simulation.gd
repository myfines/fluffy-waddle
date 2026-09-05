class_name VietnamSimulation
extends RefCounted

var year := 1965
var month := 1
var day := 1

func advance_days(count: int) -> void:
	for _i in count: _advance_one_day()

func _advance_one_day() -> void:
	day += 1
	if day > _days_in_month(year, month):
		day = 1; month += 1
		if month > 12: month = 1; year += 1

func _days_in_month(y: int, m: int) -> int:
	if m == 2: return 29 if _is_leap(y) else 28
	return 30 if [4, 6, 9, 11].has(m) else 31

func _is_leap(y: int) -> bool:
	return y % 400 == 0 or (y % 4 == 0 and y % 100 != 0)
