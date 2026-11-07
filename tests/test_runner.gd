extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	_test_states()
	_test_scoring()
	_test_swipes()
	_test_keyboard()
	_test_fairness()
	_test_collision()
	_test_saves()
	_test_content()
	await _test_world()
	await _test_scene()
	print("TrailDash: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_states() -> void:
	for source: int in RunModel.State.values():
		for target: int in RunModel.State.values():
			var run := RunModel.new()
			run.state = source as RunModel.State
			check(
				run.transition(target as RunModel.State) == (target in RunModel.TRANSITIONS[source]),
				"transition %s -> %s" % [source, target]
			)
	var paused := _running()
	paused.advance(1.0)
	paused.transition(RunModel.State.PAUSED)
	var distance := paused.distance
	paused.advance(60.0)
	check(paused.distance == distance, "pause freezes distance")
	check(paused.resume_state == RunModel.State.RUNNING, "running resume target")
	paused.state = RunModel.State.COUNTDOWN
	paused.transition(RunModel.State.PAUSED)
	check(paused.resume_state == RunModel.State.COUNTDOWN, "countdown interruption target")


func _running() -> RunModel:
	var run := RunModel.new()
	run.transition(RunModel.State.MAIN_MENU)
	run.transition(RunModel.State.COUNTDOWN)
	run.transition(RunModel.State.RUNNING)
	return run


func _test_scoring() -> void:
	var run := _running()
	run.advance(-1.0)
	check(run.elapsed == 0.0, "negative delta ignored")
	for index in 20:
		run.collect()
	check(run.tokens == 20 and run.best_combo == 20, "tokens and streak exact")
	check(run.multiplier() == 4, "combo bounded at 4x")
	check(run.score() == 1325, "incremental combo score exact")
	run.combo = 0
	check(run.multiplier() == 1, "miss resets multiplier")
	run.advance(10000.0)
	check(run.speed() == RunModel.MAX_SPEED and run.band() == 4, "speed and district bounded")
	run.transition(RunModel.State.PAUSED)
	run.collect()
	check(run.tokens == 20, "paused collection rejected")
	run.reset()
	check(
		run.score() == 0 and run.tokens == 0 and run.elapsed == 0 and run.best_combo == 0,
		"restart clears all run stats"
	)


func _test_swipes() -> void:
	var input := SwipeInput.new()
	input.begin(0, Vector2.ZERO)
	check(input.finish(0, Vector2(20, 0), 1.0) == "", "tap is not swipe")
	var positions := {
		"left": Vector2(-90, 5), "right": Vector2(90, 0), "jump": Vector2(0, -100), "slide": Vector2(0, 90)
	}
	var now := 2.0
	for direction: String in positions:
		input.begin(0, Vector2.ZERO)
		check(input.finish(0, positions[direction], now) == direction, direction + " direction")
		now += 1.0
	input.begin(1, Vector2.ZERO)
	check(input.finish(2, Vector2(100, 0), now) == "", "second finger cannot finish swipe")
	check(input.touch_id == 1, "primary finger retained")
	check(input.finish(1, Vector2(100, 0), now) == "right", "primary swipe succeeds")
	input.begin(1, Vector2.ZERO)
	check(input.finish(1, Vector2(100, 0), now + 0.01) == "", "debounce enforced")
	input.begin(1, Vector2.ZERO)
	input.cancel()
	check(input.finish(1, Vector2(100, 0), now + 2.0) == "", "pause cancels gesture")


func _test_fairness() -> void:
	var rules := SpawnRules.new()
	var repeat := SpawnRules.new()
	for seed_value in 20:
		rules.reset(seed_value)
		repeat.reset(seed_value)
		for index in 500:
			var row := rules.next_row(index % 5)
			check(row == repeat.next_row(index % 5), "seed determinism")
			check(row.obstacles[row.safe + 1] == 0, "safe lane is open")
			check(absi(row.safe - row.previous) <= 1, "adjacent safe route")
	check(
		SpawnRules.ROW_SPACING / RunModel.MAX_SPEED > SpawnRules.LANE_DURATION + 0.35,
		"maximum-speed transition has reaction margin"
	)


func _test_keyboard() -> void:
	var bindings := KeyboardControls.DEFAULTS.duplicate()
	var controls := KeyboardControls.new()
	check(KeyboardControls.valid(bindings), "default bindings valid")
	controls.waiting_for = "left"
	check(not controls.capture(KEY_ESCAPE, bindings), "pause key reserved")
	check(not controls.capture(KEY_RIGHT, bindings), "arrows reserved")
	check(controls.capture(KEY_J, bindings), "key rebind accepted")
	check(KeyboardControls.action_for(KEY_J, bindings) == "left", "new key moves left")
	controls.waiting_for = "right"
	check(controls.capture(KEY_J, bindings), "duplicate keys swap")
	check(KeyboardControls.action_for(KEY_D, bindings) == "left", "previous binding swapped")
	check(KeyboardControls.action_for(KEY_SPACE, bindings) == "jump", "space fallback")
	check(not KeyboardControls.valid({"left": 4}), "malformed bindings rejected")


func _test_collision() -> void:
	check(not SpawnRules.collides(0, 0, false), "empty lane")
	check(SpawnRules.collides(1, 0, false), "cargo ground hit")
	check(not SpawnRules.collides(1, 1.1, false), "jump clears cargo")
	check(SpawnRules.collides(2, 0, false), "standing hits gate")
	check(not SpawnRules.collides(2, 0, true), "slide clears gate")
	check(SpawnRules.collides(2, 0.5, true), "airborne slide cannot clear gate")
	check(SpawnRules.collides(3, 3, false), "garden requires lane change")


func _test_saves() -> void:
	var path := "user://test-traildash-%d.json" % Time.get_ticks_usec()
	var repository := SaveRepository.new(path)
	repository.load_save()
	check(repository.data.best_score == 0 and not repository.issue, "missing save defaults")
	var run := _running()
	run.distance = 750.0
	for index in 70:
		run.collect()
	check(repository.record_run(run), "record run write")
	var restored := SaveRepository.new(path)
	restored.load_save()
	check(restored.data.best_score == run.score() and restored.data.wallet == 70, "save roundtrip")
	check(restored.choose_color(1) and restored.data.wallet == 10, "cosmetic purchase debits once")
	check(restored.choose_color(1) and restored.data.wallet == 10, "owned color equip free")
	check(not restored.choose_color(2) and restored.data.wallet == 10, "insufficient funds rejected")
	check(not restored.choose_color(-1) and not restored.choose_color(9), "invalid cosmetic rejected")
	check(not SaveRepository._valid({"schema": 99}), "future save rejected")
	check(not SaveRepository._valid({"schema": 1, "wallet": -1}), "negative save rejected")
	check(not SaveRepository._valid({"schema": 1, "wallet": 0.5}), "fractional tokens rejected")
	check(not SaveRepository._valid({"schema": 1, "sound": "yes"}), "invalid boolean rejected")
	check(not SaveRepository._valid({"schema": 1, "unlocked": [0, 9]}), "invalid unlock rejected")
	check(SaveRepository._normalize({"schema": 0, "best_score": 4}).schema == 1, "v0 migration")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovery := SaveRepository.new(path)
	recovery.load_save()
	check(recovery.issue and recovery.data.best_score == run.score(), "backup recovery")
	check(not recovery.save(), "corrupt primary preserved")
	check(FileAccess.get_file_as_string(path) == "{broken", "recovery does not destroy evidence")
	DirAccess.remove_absolute(path)
	var interrupted := SaveRepository.new(path)
	interrupted.load_save()
	check(interrupted.data.best_score == run.score() and interrupted.issue, "missing primary recovers backup")
	check(interrupted.save(), "recovered backup can recreate primary")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _test_content() -> void:
	var text := Content.new()
	check(text.text("app.title") == "TRAILDASH", "bundled content loads")
	check(text.text("hud.distance", {"distance": 25}) == "25 m", "named interpolation")
	check(JSON.parse_string(Content.Fallback.JSON_TEXT) is Dictionary, "fallback parses")
	check(Content.new("{broken").text("app.title") == "TRAILDASH", "invalid content fallback")
	check(Content.new('{"schemaVersion":1}').text("app.title") == "TRAILDASH", "missing schema fields fallback")
	check(Content.new("", "zz").text("app.title") == "TRAILDASH", "unsupported language fallback")
	var malformed := Content.Fallback.JSON_TEXT.replace("{distance} m", "{wrong} m")
	check(Content.new(malformed).text("hud.distance", {"distance": 3}) == "3 m", "placeholder fallback")


func _test_world() -> void:
	var player := PlayerController.new()
	var world := TrackSpawner.new()
	root.add_child(player)
	root.add_child(world)
	var hits := [0]
	var coins := [0]
	world.hit.connect(func() -> void: hits[0] += 1)
	world.collected.connect(func() -> void: coins[0] += 1)
	var initial_nodes := world.get_child_count()
	for index in 10:
		player.act("left")
	check(player.current_lane == -1, "left lane clamp")
	for index in 10:
		player.act("right")
	check(player.current_lane == 1, "right lane clamp")
	player.reset()
	player.act("jump")
	var peak := 0.0
	for index in 60:
		player.advance(1.0 / 60.0, 12)
		peak = maxf(peak, player.foot_height)
	check(peak > 1.5 and player.foot_height == 0.0, "jump clears cargo and lands")
	player.act("slide")
	check(player.is_sliding(), "slide activates")
	player.advance(1.0, 12)
	check(not player.is_sliding(), "slide expires")
	player.reset()
	world.reset(9182)
	var run := _running()
	for frame in 60 * 180:
		_steer_next(world, player)
		run.advance(1.0 / 60.0)
		player.advance(1.0 / 60.0, run.speed())
		world.advance(1.0 / 60.0, run.speed(), player, run.band())
	check(hits[0] == 0 and coins[0] > 100, "three-minute real world simulation is survivable")
	check(world.rows.size() == 12 and world.get_child_count() == initial_nodes, "object pool remains bounded")
	print("Three-minute simulation: %.0f m, %d tokens, %d collisions" % [run.distance, coins[0], hits[0]])
	player.queue_free()
	world.queue_free()
	await process_frame


func _steer_next(world: TrackSpawner, player: PlayerController) -> void:
	var nearest: Dictionary = {}
	var z := -10000.0
	for row in world.rows:
		if row.root.position.z < 0.0 and row.root.position.z > z:
			nearest = row
			z = row.root.position.z
	if not nearest.is_empty():
		var lane: int = nearest.pattern.safe
		if player.current_lane != lane:
			player.act("right" if lane > player.current_lane else "left")


func _test_scene() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	# Isolate smoke-test persistence from the real player's save.
	scene.save = SaveRepository.new("user://test-scene-%d.json" % Time.get_ticks_usec())
	root.add_child(scene)
	scene.audio.enabled = false
	scene.set_physics_process(false)
	check(scene.page == "home", "main scene boot")
	scene._action("play")
	check(scene.page == "tutorial", "first-run tutorial")
	scene._action("start")
	check(scene.page == "countdown", "tutorial starts countdown")
	scene._physics_process(3.1)
	await TouchChecks.run(scene, check)
	scene._action("pause")
	check(scene.page == "paused", "pause UI")
	scene._action("settings")
	scene._action("toggle:sound")
	check(not scene.save.data.sound, "sound toggle persists")
	scene._action("back")
	check(scene.page == "paused", "settings returns to pause")
	scene._action("settings")
	scene._action("controls")
	scene._back()
	check(scene.page == "settings", "controls back returns to settings")
	scene._action("credits")
	check(scene.page == "credits", "licenses render")
	scene._back()
	scene._action("back")
	scene._action("resume")
	check(scene.run.state == RunModel.State.RUNNING, "resume running")
	scene._hit()
	scene._physics_process(0.5)
	check(scene.page == "results", "hit produces results")
	scene._action("start")
	check(scene.run.score() == 0 and scene.page == "countdown", "retry fresh run")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scene.save.path + suffix):
			DirAccess.remove_absolute(scene.save.path + suffix)
	scene.queue_free()
	await process_frame
