class_name DebugArgs
extends RefCounted
## Command line switches for testing, passed after "--":
## --seed=N --god --wave=N --level=N --spawn=<enemy>:<count> --show-states
## --bot=idle|circle|kite|wall_hug --perf-out=<path>

## The arguments of this process, parsed on first use.
static var current: DebugArgs = DebugArgs.parse(OS.get_cmdline_user_args())

var seed_value: int = -1
var god: bool = false
var wave: int = 1
var level: int = 1
var spawns: Dictionary[StringName, int] = { }
var show_states: bool = false
var bot: StringName = &""
var perf_out: String = ""
var errors: PackedStringArray = []


static func parse(args: PackedStringArray) -> DebugArgs:
	var out := DebugArgs.new()
	for arg in args:
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1)
		match key:
			"--seed":
				out.seed_value = _int(value, arg, out)
			"--god":
				out.god = true
			"--wave":
				out.wave = maxi(_int(value, arg, out), 1)
			"--level":
				out.level = maxi(_int(value, arg, out), 1)
			"--spawn":
				var count := value.get_slice(":", 1)
				if value.get_slice_count(":") == 2 and count.is_valid_int() and count.to_int() > 0:
					out.spawns[StringName(value.get_slice(":", 0))] = count.to_int()
				else:
					out.errors.append("expected --spawn=<enemy>:<count>, got " + arg)
			"--show-states":
				out.show_states = true
			"--bot":
				if Bot.MOVES.has(StringName(value)):
					out.bot = StringName(value)
				else:
					out.errors.append("unknown bot in " + arg)
			"--perf-out":
				out.perf_out = value
			_:
				out.errors.append("unknown argument " + arg)
	return out


static func _int(value: String, arg: String, out: DebugArgs) -> int:
	if not value.is_valid_int():
		out.errors.append("expected a number in " + arg)
		return 0
	return value.to_int()
