extends Node3D

var run := RunModel.new()
var save := SaveRepository.new()
var swipe := SwipeInput.new()
var keyboard := KeyboardControls.new()
var player := PlayerController.new()
var track := TrackSpawner.new()
var ui := GameUI.new()
var audio := SoundBank.new()
var camera := Camera3D.new()
var countdown: float = 3.0
var hit_delay: float = 0.0
var page: String = "home"
var settings_return: String = "home"
var hud_timer: float = 0.0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_environment()
	add_child(track)
	add_child(player)
	add_child(audio)
	add_child(ui)
	save.load_save()
	_apply_settings()
	track.collected.connect(_collect)
	track.missed.connect(func() -> void: run.combo = 0)
	track.hit.connect(_hit)
	ui.action_requested.connect(_action)
	run.transition(RunModel.State.MAIN_MENU)
	_show("home")


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("071125")
	sky_material.sky_horizon_color = Color("304b68")
	sky_material.ground_horizon_color = Color("304b68")
	sky_material.ground_bottom_color = Color("0a1327")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("98b8dc")
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -28, 0)
	light.light_color = Color("c3e4ef")
	light.light_energy = 1.3
	add_child(light)
	add_child(camera)
	camera.current = true
	camera.fov = 70
	camera.far = 185


func _physics_process(delta: float) -> void:
	match run.state:
		RunModel.State.RUNNING:
			run.advance(delta)
			player.advance(delta, run.speed())
			track.advance(delta, run.speed(), player, run.band())
		RunModel.State.COUNTDOWN:
			countdown -= delta
			if is_instance_valid(ui.countdown_label):
				ui.countdown_label.text = str(maxi(1, ceili(countdown)))
			if countdown <= 0.0:
				run.transition(RunModel.State.RUNNING)
				_show("running")
				audio.play("start")
		RunModel.State.HIT:
			hit_delay -= delta
			if hit_delay <= 0.0:
				_finish()
	hud_timer += delta
	if hud_timer > 0.1:
		hud_timer = 0.0
		ui.update_hud(run)


func _action(action: String) -> void:
	if action.begins_with("bind:"):
		keyboard.waiting_for = action.trim_prefix("bind:")
		ui.show_binding_hint(keyboard.waiting_for)
		return
	if action.begins_with("toggle:"):
		var key := action.trim_prefix("toggle:")
		save.data[key] = not save.data[key]
		save.save()
		_apply_settings()
		_show("settings")
		return
	if action.begins_with("color:"):
		save.choose_color(action.trim_prefix("color:").to_int())
		_apply_settings()
		_show("colors")
		return
	_navigate(action)


func _navigate(action: String) -> void:
	match action:
		"play":
			if not save.data.tutorial_seen:
				_action("tutorial")
			else:
				_start()
		"start":
			_start()
		"tutorial":
			if run.transition(RunModel.State.TUTORIAL):
				_show("tutorial")
		"home":
			if run.state == RunModel.State.MAIN_MENU or run.transition(RunModel.State.MAIN_MENU):
				_show("home")
		"pause":
			_pause()
		"resume":
			if run.state == RunModel.State.PAUSED and run.transition(run.resume_state):
				_show("countdown" if run.state == RunModel.State.COUNTDOWN else "running")
		"settings":
			settings_return = "paused" if run.state == RunModel.State.PAUSED else "home"
			_show("settings")
		"colors":
			_show("colors")
		"credits":
			_show("credits")
		"controls":
			_show("controls")
		"back":
			_show(settings_return)
		"save_retry":
			save.save()
			_show(page)
		"save_restore":
			save.restore_recovered()
			_show(page)
		_:
			_move(action)


func _start() -> void:
	if not run.transition(RunModel.State.COUNTDOWN):
		return
	save.data.tutorial_seen = true
	save.save()
	run.reset()
	player.reset()
	track.reset(int(Time.get_ticks_usec()))
	countdown = 3.0
	swipe.cancel()
	_show("countdown")


func _pause() -> void:
	if run.state in [RunModel.State.RUNNING, RunModel.State.COUNTDOWN]:
		run.transition(RunModel.State.PAUSED)
		swipe.cancel()
		save.save()
		_show("paused")


func _move(action: String) -> void:
	if run.state != RunModel.State.RUNNING:
		return
	player.act(action)
	if action in ["jump", "slide"]:
		audio.play(action)


func _collect() -> void:
	run.collect()
	audio.play("coin")
	if save.data.haptics:
		Input.vibrate_handheld(18)


func _hit() -> void:
	if not run.transition(RunModel.State.HIT):
		return
	hit_delay = 0.35
	audio.play("hit")
	if save.data.haptics:
		Input.vibrate_handheld(90)
	if not save.data.reduced_effects:
		player.visual.rotation.z = -0.5


func _finish() -> void:
	run.transition(RunModel.State.GAME_OVER)
	save.record_run(run)
	run.transition(RunModel.State.RESULTS)
	_show("results")


func _apply_settings() -> void:
	audio.enabled = save.data.sound
	player.reduced_effects = save.data.reduced_effects
	track.reduced_effects = save.data.reduced_effects
	player.set_color(SaveRepository.COLORS[save.data.color])
	Engine.max_fps = 30 if save.data.battery else 60


func _show(name: String) -> void:
	page = name
	keyboard.waiting_for = ""
	ui.show_page(name, run, save)
	if name == "home":
		player.reset()
		track.reset(1)
		camera.position = Vector3(7, 5, 9)
		camera.look_at(Vector3(0, 1, -1))
	else:
		camera.position = Vector3(0, 6.0, 11)
		camera.look_at(Vector3(0, 0.8, -12))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and run.state == RunModel.State.RUNNING:
		swipe.begin(event.index, event.position)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == swipe.touch_id:
		# Complete an owned gesture before the HUD can consume its release.
		if event.canceled:
			swipe.cancel()
		else:
			_move(swipe.finish(event.index, event.position, Time.get_ticks_msec() / 1000.0))
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if page == "controls" and keyboard.capture(event.physical_keycode, save.data.bindings):
			save.save()
			_show("controls")
			get_viewport().set_input_as_handled()
			return
		var action := KeyboardControls.action_for(event.physical_keycode, save.data.bindings)
		if not action.is_empty() and run.state == RunModel.State.RUNNING:
			_move(action)
			get_viewport().set_input_as_handled()
		if event.physical_keycode in [KEY_P, KEY_ESCAPE]:
			_back()
			get_viewport().set_input_as_handled()


func _back() -> void:
	if run.state in [RunModel.State.RUNNING, RunModel.State.COUNTDOWN]:
		_pause()
	elif page in ["controls", "credits"]:
		_show("settings")
	elif page == "settings":
		_show(settings_return)
	elif run.state == RunModel.State.PAUSED:
		_action("resume")
	elif page != "home":
		_action("home")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if is_instance_valid(ui) and ui.is_inside_tree():
			_pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save.save()
		get_tree().quit()
