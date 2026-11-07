class_name ControlsPanel
extends RefCounted


static func populate(parent: Node, content: Content, bindings: Dictionary, emit: Callable) -> Label:
	var hint := UIFactory.label(parent, content.text("controls.body"), 23, UIFactory.MUTED)
	for action: String in KeyboardControls.DEFAULTS:
		var title := content.text(
			"controls.binding",
			{"action": content.text("controls." + action), "key": OS.get_keycode_string(bindings[action])}
		)
		UIFactory.button(parent, title, emit.bind("bind:" + action))
	return hint
