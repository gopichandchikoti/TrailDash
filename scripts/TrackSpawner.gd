class_name TrackSpawner
extends Node3D

signal collected
signal missed
signal hit

const ROW_COUNT: int = 12
const TRACK_COUNT: int = 9

var rules := SpawnRules.new()
var rows: Array[Dictionary] = []
var tracks: Array[Node3D] = []
var reduced_effects: bool = false


func _ready() -> void:
	for index in TRACK_COUNT:
		tracks.append(WorldArt.track(self, index))
	for index in ROW_COUNT:
		rows.append(_create_row())
	reset(1)


func _create_row() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var variants: Array[Node3D] = []
	for lane in range(-1, 2):
		for kind in range(1, 4):
			var obstacle := WorldArt.obstacle(root, kind)
			obstacle.position.x = lane * SpawnRules.LANE_WIDTH
			variants.append(obstacle)
	var coin := WorldArt.token(root)
	return {"root": root, "variants": variants, "coin": coin, "pattern": {}, "resolved": false}


func reset(seed_value: int) -> void:
	rules.reset(seed_value)
	for index in tracks.size():
		tracks[index].position.z = 12 - index * 24
	for index in rows.size():
		_configure(rows[index], -40.0 - index * SpawnRules.ROW_SPACING, 0)


func _configure(row: Dictionary, z: float, band: int) -> void:
	row.pattern = rules.next_row(band)
	row.root.position.z = z
	row.resolved = false
	row.coin.visible = true
	row.coin.position.x = row.pattern.safe * SpawnRules.LANE_WIDTH
	for index in row.variants.size():
		var lane: int = int(index / 3.0)
		row.variants[index].visible = row.pattern.obstacles[lane] == index % 3 + 1


func advance(delta: float, speed: float, player: PlayerController, band: int) -> void:
	var movement := delta * speed
	for track in tracks:
		track.position.z += movement
		if track.position.z > 36.0:
			track.position.z -= TRACK_COUNT * 24.0
	for row in rows:
		var before: float = row.root.position.z
		row.root.position.z += movement
		if not reduced_effects:
			row.coin.rotation.y += delta * 1.4
		if not row.resolved and before < 0.0 and row.root.position.z >= 0.0:
			_resolve(row, player)
		if row.root.position.z > 15.0:
			_configure(row, _farthest_z() - SpawnRules.ROW_SPACING, band)


func _farthest_z() -> float:
	var farthest := 0.0
	for row in rows:
		farthest = minf(farthest, row.root.position.z)
	return farthest


func _resolve(row: Dictionary, player: PlayerController) -> void:
	row.resolved = true
	var safe_x: float = row.pattern.safe * SpawnRules.LANE_WIDTH
	if absf(player.position.x - safe_x) < 0.85 and player.foot_height < 1.5:
		row.coin.visible = false
		collected.emit()
	else:
		missed.emit()
	for lane in range(-1, 2):
		var kind: int = row.pattern.obstacles[lane + 1]
		if absf(player.position.x - lane * SpawnRules.LANE_WIDTH) < 1.05:
			if SpawnRules.collides(kind, player.foot_height, player.is_sliding()):
				hit.emit()
				return
