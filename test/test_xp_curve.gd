extends GutTest


func _curve(base: float, growth: float, exponent: float) -> XpCurve:
	var c := XpCurve.new()
	c.base = base
	c.growth = growth
	c.exponent = exponent
	return c


func test_level_one_costs_base() -> void:
	assert_eq(_curve(12.0, 1.5, 1.3).xp_to_next(1), 12)


func test_known_value() -> void:
	# 10 + 2 * 3^2 = 28
	assert_eq(_curve(10.0, 2.0, 2.0).xp_to_next(4), 28)


func test_levels_below_one_cost_like_level_one() -> void:
	var c := _curve(12.0, 1.5, 1.3)
	assert_eq(c.xp_to_next(0), c.xp_to_next(1))
	assert_eq(c.xp_to_next(-5), c.xp_to_next(1))


func test_tuned_curve_never_gets_cheaper() -> void:
	var c := load("res://data/tuning/xp_curve.tres") as XpCurve
	assert_not_null(c, "xp_curve.tres loads as XpCurve")
	for level in range(1, 60):
		assert_true(c.xp_to_next(level + 1) >= c.xp_to_next(level), "level %d" % level)
