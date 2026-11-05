extends GutTest
## Guards the pixel-perfect display settings the whole art style depends on.


func test_viewport_is_640x360() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)


func test_stretch_is_integer_viewport() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")


func test_texture_filter_is_nearest() -> void:
	var key := "rendering/textures/canvas_textures/default_texture_filter"
	assert_true(ProjectSettings.has_setting(key), "setting key exists in this Godot version")
	# Project setting uses the Viewport enum (Nearest = 0), not CanvasItem's (Nearest = 1).
	assert_eq(ProjectSettings.get_setting(key), Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
