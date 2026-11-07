class_name SaveRepository
extends RefCounted

const DEFAULTS: Dictionary = {
	"schema": 1,
	"best_score": 0,
	"best_distance": 0,
	"wallet": 0,
	"total_tokens": 0,
	"tutorial_seen": false,
	"sound": true,
	"haptics": true,
	"reduced_effects": false,
	"buttons": true,
	"battery": false,
	"color": 0,
	"unlocked": [0]
}
const COLORS: Array[Color] = [Color("6ff2cd"), Color("ff876b"), Color("b6a5ff")]
const COST: int = 60

var data: Dictionary = DEFAULTS.duplicate(true)
var path: String
var issue: bool = false
var writable: bool = true
var recovery_available: bool = false


func _init(save_path: String = "user://traildash.json") -> void:
	path = save_path
	data.bindings = KeyboardControls.DEFAULTS.duplicate()


func load_save() -> void:
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var backup_only: Variant = _read_json(path + ".bak")
			issue = true
			writable = _valid(backup_only)
			if writable:
				data = _normalize(backup_only)
		return
	var parsed: Variant = _read_json(path)
	if _valid(parsed):
		data = _normalize(parsed)
		return
	issue = true
	writable = false
	var backup: Variant = _read_json(path + ".bak")
	if _valid(backup):
		data = _normalize(backup)
		recovery_available = true


static func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return null
	return parser.data


func restore_recovered() -> bool:
	if not recovery_available:
		return false
	var preserved := path + ".rejected-" + str(Time.get_ticks_usec())
	if DirAccess.rename_absolute(path, preserved) != OK:
		return false
	writable = true
	recovery_available = false
	return save()


func save() -> bool:
	if not writable:
		return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		issue = true
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(path):
		var error := DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			issue = true
			return false
	var result := DirAccess.rename_absolute(temp, path)
	issue = result != OK
	return not issue


func record_run(run: RunModel) -> bool:
	data.best_score = maxi(data.best_score, run.score())
	data.best_distance = maxi(data.best_distance, int(run.distance))
	data.wallet += run.tokens
	data.total_tokens += run.tokens
	return save()


func choose_color(index: int) -> bool:
	if index < 0 or index >= COLORS.size():
		return false
	if not index in data.unlocked:
		if data.wallet < COST:
			return false
		data.wallet -= COST
		data.unlocked.append(index)
	data.color = index
	return save()


static func _valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not _integer(value.get("schema", 0), 0, 1):
		return false
	for key in ["best_score", "best_distance", "wallet", "total_tokens", "color"]:
		var number: Variant = value.get(key, 0)
		if not _integer(number, 0, 1000000000):
			return false
	for key in ["tutorial_seen", "sound", "haptics", "reduced_effects", "buttons", "battery"]:
		if value.has(key) and not value[key] is bool:
			return false
	if value.has("bindings") and not KeyboardControls.valid(value.bindings):
		return false
	return _valid_unlocks(value)


static func _valid_unlocks(value: Dictionary) -> bool:
	var unlocks: Variant = value.get("unlocked", [0])
	if not unlocks is Array or unlocks.size() > 3 or not unlocks.has(0.0) and not unlocks.has(0):
		return false
	for index: Variant in unlocks:
		if not _integer(index, 0, 2):
			return false
	return value.get("color", 0) in unlocks


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and floorf(value) == value


static func _normalize(value: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for key: String in DEFAULTS:
		if value.has(key):
			result[key] = value[key]
	for key in ["best_score", "best_distance", "wallet", "total_tokens", "color"]:
		result[key] = int(result[key])
	var unlocks: Array[int] = []
	for index: Variant in result.unlocked:
		unlocks.append(int(index))
	result.unlocked = unlocks
	result.bindings = KeyboardControls.DEFAULTS.duplicate()
	if value.has("bindings"):
		for action: String in result.bindings:
			result.bindings[action] = int(value.bindings[action])
	result.schema = 1
	return result
