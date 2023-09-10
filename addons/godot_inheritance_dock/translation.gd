@tool
extends Object

## A static class for retrieving localized text throughout the plugin.

const DELIMITER = "|"

## Object holding all translations for the active language in the current editor session.
static var translation: Translation

## Object holding all available translations for the languages from [code]translation.csv[/code].
static var languages := {}

## Embrace strings with this function to be marked for translation. The string
## will return unchanged, if a term for the destination language is not available.
static func localize(message: StringName, context: StringName = "") -> String:
	if not translation:
		_setup()

	var new_message := translation.get_message(message, context)
	if new_message.is_empty():
		new_message = message
	return new_message.c_unescape()

static func _setup() -> void:
	var locale := EditorPlugin.new().get_editor_interface().get_editor_settings().get_setting("interface/editor/editor_language") as String

	var translations_file_path := preload("translation.gd").new().get_script().get_path().get_base_dir().path_join("translation.csv") as String
	var file := FileAccess.open(translations_file_path, FileAccess.READ)
	if file.get_error() == OK:
		for lang_id in file.get_csv_line(DELIMITER).slice(1):
			#print("Add {0} as language.".format([lang_id]))
			languages[lang_id] = Translation.new()
			languages[lang_id].locale = lang_id
		#print()
		while not file.eof_reached():
			var key_word_languages := file.get_csv_line(DELIMITER)
			if key_word_languages.size() <= 1: # empty of invalid line
				continue

			#print('For "{0}"'.format([key_word_languages[0]]))
			for index in key_word_languages.size():
				# Skip keys column
				if index == 0:
					continue

				var lang_id_as_index: String = languages.keys()[index - 1]
				var translation: Translation = languages[lang_id_as_index]
				#print('|-> [{0}] "{1}"'.format([lang_id_as_index, key_word_languages[index]]))
				translation.add_message(key_word_languages[0], key_word_languages[index])
			#print()

	# Pick translation for current editor language
	translation = languages[locale]
	#print(translation.get_translated_message_list(), "\n")
