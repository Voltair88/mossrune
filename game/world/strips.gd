class_name Strips
extends RefCounted
## Builds SpriteFrames from the generated PNG strips (square frames side by side).
## One SpriteFrames per sheet and animation set, shared by every node that uses it.

const SPRITE_DIR := "res://assets/sprites/"

static var _cache: Dictionary[String, SpriteFrames] = { }


## anims maps an animation name to [fps, loops].
static func frames(sheet: String, anims: Dictionary) -> SpriteFrames:
	var key := sheet + ":" + str(anims.keys())
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim: StringName in anims:
		var tex := load(SPRITE_DIR + "%s_%s.png" % [sheet, anim]) as Texture2D
		var side := tex.get_height()
		sf.add_animation(anim)
		sf.set_animation_speed(anim, anims[anim][0])
		sf.set_animation_loop(anim, anims[anim][1])
		for i in floori(tex.get_width() / float(side)):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * side, 0, side, side)
			sf.add_frame(anim, at)
	_cache[key] = sf
	return sf
