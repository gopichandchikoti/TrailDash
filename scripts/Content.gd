class_name Content
extends RefCounted

const Fallback = preload("res://scripts/ContentFallback.gd")
var entries: Dictionary = {}


func _init(model_text: String = "", preferred_locale: String = "") -> void:
	var fallback: Dictionary = _parse(Fallback.JSON_TEXT)
	if model_text.is_empty():
		model_text = FileAccess.get_file_as_string("res://public/traildash.model.json")
	var value: Variant = _parse(model_text)
	if not _valid(value, fallback.locales[fallback.defaultLocale]):
		value = fallback
	var dictionaries: Dictionary = value.locales
	var locale := preferred_locale if not preferred_locale.is_empty() else OS.get_locale_language()
	entries = dictionaries.get(locale, dictionaries[value.defaultLocale])


static func _parse(source: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(source) == OK else null


static func _valid(value: Variant, reference: Dictionary) -> bool:
	if not value is Dictionary or value.get("schemaVersion") != 1:
		return false
	var locales: Variant = value.get("locales")
	if not locales is Dictionary or not locales.has(value.get("defaultLocale")):
		return false
	for locale: Variant in locales:
		if not locales[locale] is Dictionary or locales[locale].size() != reference.size():
			return false
		for key: String in reference:
			if not locales[locale].get(key) is String or locales[locale][key].is_empty():
				return false
			if _placeholders(locales[locale][key]) != _placeholders(reference[key]):
				return false
	return true


static func _placeholders(template: String) -> Array[String]:
	var expression := RegEx.new()
	expression.compile("\\{\\w+\\}")
	var names: Array[String] = []
	for result: RegExMatch in expression.search_all(template):
		names.append(result.get_string())
	names.sort()
	return names


func text(key: String, parameters: Dictionary = {}) -> String:
	var result: String = entries.get(key, "")
	for name: String in parameters:
		result = result.replace("{" + name + "}", str(parameters[name]))
	return result
