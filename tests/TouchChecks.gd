class_name TouchChecks
extends RefCounted


static func run(scene: Node, check: Callable) -> void:
	check.call(scene.run.state == RunModel.State.RUNNING, "countdown to running")
	await scene.get_tree().process_frame
	var viewport: Viewport = scene.get_viewport()
	var origin := viewport.get_visible_rect().size * 0.5
	_send(viewport, origin, true)
	_send(viewport, origin + Vector2(120, 0), false, {"canceled": true})
	check.call(scene.player.current_lane == 0, "canceled Android gesture does not move the runner")
	check.call(scene.swipe.touch_id == -1, "canceled gesture releases its finger")
	scene.player.reset()
	scene.swipe.cancel()
	scene.swipe.last_action = -1.0
	var pause: Button = _pause_button(scene)
	check.call(pause != null, "pause button is present for input routing check")
	if pause == null:
		return
	_send(viewport, origin, true)
	_send(viewport, pause.get_global_rect().get_center(), false)
	check.call(scene.swipe.touch_id == -1, "swipe ending over the HUD releases ownership")
	check.call(scene.run.state == RunModel.State.RUNNING, "swipe ending over HUD does not press Pause")
	scene.player.reset()
	scene.swipe.cancel()
	scene.swipe.last_action = -1.0
	_send(viewport, origin, true)
	_send(viewport, origin + Vector2(120, 0), false)
	check.call(scene.player.current_lane == 1, "next swipe starts from its own touch position")
	scene.player.reset()
	scene.swipe.last_action = -1.0
	_send(viewport, origin, true)
	_send(viewport, origin + Vector2(-120, 0), false, {"canceled": true, "index": 1})
	check.call(scene.swipe.touch_id == 0, "canceling another finger preserves the primary gesture")
	_send(viewport, origin + Vector2(-120, 0), false)
	check.call(scene.player.current_lane == -1, "primary finger still completes after secondary cancellation")
	scene.player.reset()
	_send(viewport, pause.get_global_rect().get_center(), true)
	_send(viewport, pause.get_global_rect().get_center(), false)
	check.call(scene.page == "paused", "ordinary HUD button tap still pauses")
	scene._action("resume")
	scene.audio.enabled = false
	scene.swipe.last_action = -1.0
	_menu_reset(scene, check)


static func _menu_reset(scene: Node, check: Callable) -> void:
	scene.player.act("right")
	scene.player.act("slide")
	scene.player.advance(0.1, scene.run.speed())
	scene._action("pause")
	scene._action("home")
	check.call(
		scene.player.position == Vector3.ZERO and scene.player.visual.scale == Vector3.ONE,
		"returning home restores the courier lane and standing pose"
	)
	check.call(scene.track.rows[0].root.position.z == -40.0, "returning home restores the menu track")
	scene._action("start")
	scene._physics_process(3.1)
	scene.audio.enabled = false


static func _pause_button(scene: Node) -> Button:
	for button: Button in scene.ui.hud.find_children("*", "Button", true, false):
		if button.accessibility_name == scene.ui.content.text("hud.pause_name"):
			return button
	return null


static func _send(viewport: Viewport, at: Vector2, pressed: bool, options: Dictionary = {}) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = options.get("index", 0)
	event.pressed = pressed
	event.canceled = options.get("canceled", false)
	viewport.push_input(event, true)
