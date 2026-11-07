class_name CreditsPanel
extends RefCounted


static func populate(parent: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(610, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var text := RichTextLabel.new()
	text.custom_minimum_size.x = 580
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 19)
	text.text = Engine.get_license_text() + "\n\n"
	for notice: Dictionary in Engine.get_copyright_info():
		text.text += str(notice.name) + "\n"
		for part: Dictionary in notice.parts:
			text.text += "\n".join(part.copyright) + "\n" + str(part.license) + "\n"
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		text.text += "\n" + name + "\n" + str(licenses[name]) + "\n"
	scroll.add_child(text)
