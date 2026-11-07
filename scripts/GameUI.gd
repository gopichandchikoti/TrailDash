class_name GameUI
extends CanvasLayer

signal action_requested(action: String)

var content := Content.new()
var root := Control.new()
var page := Control.new()
var hud := Control.new()
var distance_label: Label
var tokens_label: Label
var combo_label: Label
var speed_label: Label
var countdown_label: Label
var warning_label: Label
var safe_margin: MarginContainer
var binding_hint: Label


func _ready() -> void:
	add_child(root)
	UIFactory.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_margin = UIFactory.margin(root, 34)
	UIFactory.fill(safe_margin)
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe_content := Control.new()
	safe_margin.add_child(safe_content)
	safe_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_content.add_child(hud)
	safe_content.add_child(page)
	UIFactory.fill(hud)
	UIFactory.fill(page)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	if not OS.has_feature("android"):
		return
	var area := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var scale_y := root.size.y / maxf(screen.y, 1.0)
	safe_margin.add_theme_constant_override("margin_top", 28 + int(area.position.y * scale_y))
	var bottom := screen.y - area.end.y
	safe_margin.add_theme_constant_override("margin_bottom", 28 + int(bottom * scale_y))


func show_page(name: String, run: RunModel, save: SaveRepository) -> void:
	_clear(page)
	_clear(hud)
	countdown_label = null
	if name in ["running", "countdown", "paused"]:
		_build_hud(save)
	match name:
		"home":
			_home(save)
		"tutorial":
			_tutorial()
		"paused":
			_paused()
		"settings":
			_settings(save)
		"colors":
			_colors(save)
		"credits":
			var column := _modal("credits.title")
			UIFactory.label(column, content.text("credits.original"), 20, UIFactory.MUTED)
			CreditsPanel.populate(column)
			_button(column, "common.back", "settings")
		"controls":
			var column := _modal("controls.title")
			binding_hint = ControlsPanel.populate(column, content, save.data.bindings, _emit)
			_button(column, "common.back", "settings")
		"results":
			_results(run, save)
		"countdown":
			var column := _modal("countdown.ready", false)
			countdown_label = UIFactory.label(column, "3", 120, UIFactory.ACCENT)
	if save.issue:
		_warning(save)
	update_hud(run)
	_focus_first(page)


func update_hud(run: RunModel) -> void:
	if not is_instance_valid(distance_label) or distance_label.is_queued_for_deletion():
		return
	distance_label.text = content.text("hud.distance", {"distance": int(run.distance)})
	tokens_label.text = content.text("hud.tokens", {"tokens": run.tokens})
	combo_label.text = content.text("hud.combo", {"multiplier": run.multiplier()})
	speed_label.text = content.text("hud.band", {"speed": int(run.speed() * 3.6), "band": run.band() + 1})


func _home(save: SaveRepository) -> void:
	var header := UIFactory.stack(page, 8)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.position.y = 70
	UIFactory.label(header, content.text("menu.eyebrow"), 20, UIFactory.ACCENT)
	UIFactory.label(header, content.text("app.title"), 76)
	UIFactory.label(header, content.text("app.tagline"), 17, UIFactory.MUTED)
	var lower := VBoxContainer.new()
	page.add_child(lower)
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lower.add_theme_constant_override("separation", 14)
	UIFactory.label(lower, content.text("menu.description"), 25)
	UIFactory.label(
		lower,
		content.text("menu.records", {"score": save.data.best_score, "distance": save.data.best_distance}),
		21,
		UIFactory.MUTED
	)
	_button(lower, "menu.play", "play", true)
	var row := HBoxContainer.new()
	lower.add_child(row)
	row.add_theme_constant_override("separation", 12)
	_button(row, "menu.tutorial", "tutorial")
	_button(row, "menu.settings", "settings")
	_button(lower, "menu.colors", "colors")
	UIFactory.label(lower, content.text("menu.footer"), 15, UIFactory.MUTED)


func _modal(title: String, dim: bool = true) -> VBoxContainer:
	if dim:
		var tint := ColorRect.new()
		tint.color = Color(0.025, 0.055, 0.1, 0.94)
		page.add_child(tint)
		UIFactory.fill(tint)
	var center := CenterContainer.new()
	page.add_child(center)
	UIFactory.fill(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UIFactory.stack(center, 22)
	column.custom_minimum_size.x = 610
	UIFactory.label(column, content.text("menu.eyebrow"), 17, UIFactory.ACCENT)
	UIFactory.label(column, content.text(title), 44)
	return column


func _tutorial() -> void:
	var column := _modal("tutorial.title")
	UIFactory.label(column, content.text("tutorial.body"), 27)
	UIFactory.label(column, content.text("tutorial.keyboard"), 21, UIFactory.MUTED)
	_button(column, "tutorial.start", "start", true)
	_button(column, "common.back", "home")


func _paused() -> void:
	var column := _modal("pause.title")
	UIFactory.label(column, content.text("pause.body"), 24, UIFactory.MUTED)
	_button(column, "pause.resume", "resume", true)
	_button(column, "menu.settings", "settings")
	_button(column, "common.home", "home")


func _settings(save: SaveRepository) -> void:
	var column := _modal("settings.title")
	for key in ["sound", "haptics", "reduced_effects", "buttons", "battery"]:
		var state := content.text("common.on" if save.data[key] else "common.off")
		var title := content.text("settings." + key) + "   " + state
		UIFactory.button(column, title, _emit.bind("toggle:" + key))
	UIFactory.label(column, content.text("settings.privacy"), 20, UIFactory.MUTED)
	_button(column, "credits.title", "credits")
	_button(column, "controls.title", "controls")
	_button(column, "common.back", "back", true)


func _colors(save: SaveRepository) -> void:
	var column := _modal("colors.title")
	UIFactory.label(column, content.text("colors.body"), 24, UIFactory.MUTED)
	UIFactory.label(column, content.text("menu.wallet", {"tokens": save.data.wallet}), 26, WorldArt.GOLD)
	var names := ["mint", "coral", "lilac"]
	for index in names.size():
		var key := "colors.equip" if index in save.data.unlocked else "colors.buy"
		if index == save.data.color:
			key = "colors.selected"
		var title := content.text(key, {"name": content.text("colors." + names[index])})
		var view := UIFactory.button(column, title, _emit.bind("color:" + str(index)), index == save.data.color)
		view.disabled = not index in save.data.unlocked and save.data.wallet < SaveRepository.COST
	var badges: Dictionary = {}
	for pair in [["one", 500], ["two", 1500], ["three", 3000]]:
		badges[pair[0]] = content.text("common.check" if save.data.best_distance >= pair[1] else "common.empty")
	UIFactory.label(column, content.text("menu.milestone", badges), 19, UIFactory.MUTED)
	_button(column, "common.back", "home")


func _results(run: RunModel, save: SaveRepository) -> void:
	var column := _modal("results.title")
	var key := "results.record" if run.score() >= save.data.best_score else "results.subtitle"
	UIFactory.label(column, content.text(key), 20, UIFactory.ACCENT)
	UIFactory.label(column, content.text("results.score", {"score": run.score()}), 104)
	UIFactory.label(column, content.text("results.score_label"), 19, UIFactory.MUTED)
	UIFactory.label(
		column,
		content.text(
			"results.stats",
			{"distance": int(run.distance), "tokens": run.tokens, "combo": run.best_combo, "seconds": int(run.elapsed)}
		),
		26
	)
	_button(column, "results.retry", "start", true)
	_button(column, "common.home", "home")


func _build_hud(save: SaveRepository) -> void:
	var column := UIFactory.stack(hud, 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	column.add_child(bar)
	distance_label = UIFactory.label(bar, "", 46)
	distance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tokens_label = UIFactory.label(bar, "", 30, WorldArt.GOLD)
	tokens_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tokens_label.custom_minimum_size.x = 130
	var pause_button := _button(bar, "hud.pause", "pause")
	pause_button.custom_minimum_size = Vector2(78, 78)
	pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.accessibility_name = content.text("hud.pause_name")
	speed_label = UIFactory.label(column, "", 18, UIFactory.MUTED)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label = UIFactory.label(column, "", 20, UIFactory.ACCENT)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if save.data.buttons:
		_touch_buttons()


func _touch_buttons() -> void:
	var column := UIFactory.stack(hud, 14)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UIFactory.label(column, content.text("hud.hint"), 17, UIFactory.MUTED)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_theme_constant_override("separation", 10)
	for action in ["left", "jump", "slide", "right"]:
		var view := _button(row, "hud." + action, action)
		view.custom_minimum_size.y = 94
		view.add_theme_font_size_override("font_size", 23)
		view.accessibility_name = content.text("controls." + action)


func _warning(save: SaveRepository) -> void:
	var box := UIFactory.stack(page, 8)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	warning_label = UIFactory.label(box, content.text("save.warning"), 19, WorldArt.GOLD)
	if save.recovery_available:
		_button(box, "save.restore", "save_restore")
	elif save.writable:
		_button(box, "save.retry", "save_retry")


func _button(parent: Node, key: String, action: String, primary: bool = false) -> Button:
	return UIFactory.button(parent, content.text(key), _emit.bind(action), primary)


func _emit(action: String) -> void:
	action_requested.emit(action)


func show_binding_hint(action: String) -> void:
	binding_hint.text = content.text("controls.waiting", {"action": content.text("controls." + action)})


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _focus_first(parent: Node) -> bool:
	for child in parent.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return true
		if _focus_first(child):
			return true
	return false
