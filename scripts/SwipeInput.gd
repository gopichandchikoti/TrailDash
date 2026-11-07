class_name SwipeInput
extends RefCounted

const THRESHOLD: float = 42.0
const DEBOUNCE: float = 0.13

var origin := Vector2.ZERO
var touch_id: int = -1
var last_action: float = -1.0


func begin(index: int, position: Vector2) -> void:
	if touch_id == -1:
		touch_id = index
		origin = position


func finish(index: int, position: Vector2, now: float) -> String:
	if index != touch_id:
		return ""
	touch_id = -1
	var difference := position - origin
	if difference.length() < THRESHOLD or now - last_action < DEBOUNCE:
		return ""
	last_action = now
	if absf(difference.x) > absf(difference.y):
		return "right" if difference.x > 0 else "left"
	return "slide" if difference.y > 0 else "jump"


func cancel() -> void:
	touch_id = -1
