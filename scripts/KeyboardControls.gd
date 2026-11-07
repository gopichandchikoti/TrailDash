class_name KeyboardControls
extends RefCounted

const DEFAULTS: Dictionary = {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "slide": KEY_S}
const FIXED: Dictionary = {KEY_LEFT: "left", KEY_RIGHT: "right", KEY_UP: "jump", KEY_DOWN: "slide", KEY_SPACE: "jump"}

var waiting_for: String = ""


func capture(key: int, bindings: Dictionary) -> bool:
	if waiting_for.is_empty() or key in FIXED or key in [KEY_P, KEY_ESCAPE] or key <= 0:
		return false
	var previous: int = bindings[waiting_for]
	for action: String in bindings:
		if bindings[action] == key:
			bindings[action] = previous
	bindings[waiting_for] = key
	waiting_for = ""
	return true


static func action_for(key: int, bindings: Dictionary) -> String:
	for action: String in bindings:
		if bindings[action] == key:
			return action
	return FIXED.get(key, "")


static func valid(bindings: Variant) -> bool:
	if not bindings is Dictionary or bindings.size() != DEFAULTS.size():
		return false
	var used: Array[int] = []
	for action: String in DEFAULTS:
		var key: Variant = bindings.get(action)
		if not SaveRepository._integer(key, 1, 1000000000):
			return false
		if int(key) in used or int(key) in FIXED or int(key) in [KEY_P, KEY_ESCAPE]:
			return false
		used.append(int(key))
	return true
