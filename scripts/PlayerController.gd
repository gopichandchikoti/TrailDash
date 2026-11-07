class_name PlayerController
extends Node3D

var current_lane: int = 0
var foot_height: float = 0.0
var vertical_speed: float = 0.0
var slide_time: float = 0.0
var motion_time: float = 0.0
var reduced_effects: bool = false
var visual := Node3D.new()
var body: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D


func _ready() -> void:
	add_child(visual)
	body = WorldArt.box(visual, Vector3(0.62, 0.74, 0.42), Vector3(0, 1.1, 0), WorldArt.MINT)
	WorldArt.box(visual, Vector3(0.54, 0.5, 0.52), Vector3(0, 1.74, 0), Color("e1f9ed"))
	WorldArt.box(visual, Vector3(0.57, 0.19, 0.09), Vector3(0, 1.76, -0.29), Color("10283d"))
	WorldArt.box(visual, Vector3(0.45, 0.55, 0.25), Vector3(0, 1.1, 0.32), WorldArt.CORAL)
	left_leg = WorldArt.box(visual, Vector3(0.22, 0.6, 0.24), Vector3(-0.19, 0.36, 0), WorldArt.INK)
	right_leg = WorldArt.box(visual, Vector3(0.22, 0.6, 0.24), Vector3(0.19, 0.36, 0), WorldArt.INK)
	for side in [-1, 1]:
		WorldArt.box(visual, Vector3(0.19, 0.65, 0.2), Vector3(side * 0.43, 1.04, 0), WorldArt.CORAL)
		WorldArt.box(visual, Vector3(0.26, 0.13, 0.4), Vector3(side * 0.19, 0.08, -0.06), Color("e1f9ed"))


func reset() -> void:
	current_lane = 0
	foot_height = 0.0
	vertical_speed = 0.0
	slide_time = 0.0
	motion_time = 0.0
	position = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.rotation = Vector3.ZERO
	left_leg.rotation = Vector3.ZERO
	right_leg.rotation = Vector3.ZERO


func set_color(color: Color) -> void:
	body.material_override = WorldArt.material(color)


func act(action: String) -> void:
	match action:
		"left":
			current_lane = maxi(-1, current_lane - 1)
		"right":
			current_lane = mini(1, current_lane + 1)
		"jump":
			if foot_height < 0.01:
				vertical_speed = 9.7
				slide_time = 0.0
		"slide":
			if foot_height < 0.01:
				slide_time = 0.9


func advance(delta: float, speed: float) -> void:
	position.x = move_toward(
		position.x, current_lane * SpawnRules.LANE_WIDTH, SpawnRules.LANE_WIDTH / SpawnRules.LANE_DURATION * delta
	)
	vertical_speed -= 25.0 * delta
	foot_height = maxf(0.0, foot_height + vertical_speed * delta)
	if foot_height == 0.0:
		vertical_speed = 0.0
	slide_time = maxf(0.0, slide_time - delta)
	position.y = foot_height
	motion_time += delta * speed
	_animate(delta)


func _animate(delta: float) -> void:
	visual.scale.y = move_toward(visual.scale.y, 0.42 if is_sliding() else 1.0, delta * 12.0)
	if reduced_effects:
		visual.rotation.z = 0.0
		left_leg.rotation.x = 0.0
		right_leg.rotation.x = 0.0
		return
	var stride := sin(motion_time * 1.4) * 0.55 if foot_height == 0 else 0.25
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	visual.rotation.z = clampf((position.x - current_lane * SpawnRules.LANE_WIDTH) * 0.12, -0.18, 0.18)


func is_sliding() -> bool:
	return slide_time > 0.0 and foot_height < 0.15
