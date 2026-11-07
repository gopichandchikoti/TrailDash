class_name SpawnRules
extends RefCounted

const ROW_SPACING: float = 19.0
const LANE_WIDTH: float = 2.3
const LANE_DURATION: float = 0.18

var rng := RandomNumberGenerator.new()
var safe_lane: int = 0
var row_index: int = 0


func reset(seed_value: int) -> void:
	rng.seed = seed_value
	safe_lane = 0
	row_index = 0


func next_row(band: int) -> Dictionary:
	var previous := safe_lane
	# One adjacent transition is always enough. Never require a two-lane crossing.
	safe_lane = clampi(safe_lane + rng.randi_range(-1, 1), -1, 1)
	var obstacles: Array[int] = [0, 0, 0]
	var density := minf(0.55 + clampi(band, 0, 4) * 0.12, 1.0)
	for lane in range(-1, 2):
		if lane != safe_lane and rng.randf() < density:
			obstacles[lane + 1] = rng.randi_range(1, 3)
	row_index += 1
	return {"safe": safe_lane, "previous": previous, "obstacles": obstacles, "index": row_index}


static func collides(kind: int, foot_height: float, sliding: bool) -> bool:
	match kind:
		1:
			return foot_height < 1.05
		2:
			return not sliding or foot_height > 0.15
		3:
			return true
	return false
