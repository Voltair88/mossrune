class_name SaveStore
extends RefCounted
## Records and settings in user://save.cfg. A save is written whole to a temp file
## and then renamed over the old one, so a crash mid-write leaves the old save.
## An unreadable file, or one from a newer version, loads as defaults.

const PATH := "user://save.cfg"
const VERSION := 1
const SECTION := "save"

var best_seconds: float = 0.0
var best_level: int = 0
var shake: bool = true
var flashes: bool = true


static func read(path: String) -> SaveStore:
	var s := SaveStore.new()
	if not FileAccess.file_exists(path):
		return s
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		push_warning("save: cannot parse %s, using defaults" % path)
		return s
	var version: Variant = cfg.get_value(SECTION, "version", 0)
	# shortcut: no migrations yet, version 1 is the first; add one step per bump.
	if not version is int or version != VERSION:
		push_warning("save: unknown version %s in %s, using defaults" % [version, path])
		return s
	s.best_seconds = _number(cfg, "best_seconds", s.best_seconds)
	s.best_level = int(_number(cfg, "best_level", s.best_level))
	s.shake = _flag(cfg, "shake", s.shake)
	s.flashes = _flag(cfg, "flashes", s.flashes)
	return s


## Keeps the better time and level. Returns true if either was beaten.
func record(seconds: float, level: int) -> bool:
	var better := seconds > best_seconds or level > best_level
	best_seconds = maxf(best_seconds, seconds)
	best_level = maxi(best_level, level)
	return better


func write(path: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "version", VERSION)
	cfg.set_value(SECTION, "best_seconds", best_seconds)
	cfg.set_value(SECTION, "best_level", best_level)
	cfg.set_value(SECTION, "shake", shake)
	cfg.set_value(SECTION, "flashes", flashes)
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp, path)


static func _number(cfg: ConfigFile, key: String, fallback: float) -> float:
	var v: Variant = cfg.get_value(SECTION, key, fallback)
	return float(v) if (v is int or v is float) and float(v) >= 0.0 else fallback


static func _flag(cfg: ConfigFile, key: String, fallback: bool) -> bool:
	var v: Variant = cfg.get_value(SECTION, key, fallback)
	return v if v is bool else fallback
