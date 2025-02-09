@tool
extends HBoxContainer

## Contains one RegEx rule inside a [code]FilterMenu[/code].

##### SIGNALS #####

signal checkbox_updated
signal filter_rearranged(p_item: FilterMenuItem, p_direction: ButtonEvent)
signal name_updated
signal regex_updated
signal item_removed(p_item: FilterMenuItem)
signal item_sync_requested(p_item: FilterMenuItem)

##### CLASSES #####

##### CONSTANTS #####

enum ButtonEvent {
	BUTTON_MOVE_UP = -1,
	BUTTON_MOVE_DOWN = 1,
}

const REGEX_OK = preload("icons/icon_import_check.svg")
const REGEX_ERROR = preload("icons/icon_error_sign.svg")
const REGEX_MAP = {
	true: REGEX_OK,
	false: REGEX_ERROR
}

const FilterMenuItem = preload("filter_menu_item.gd")
const PluginTranslation = preload("plugin_translation.gd")

##### EXPORTS #####

##### MEMBERS #####

# public

# public onready
@onready var check := $CheckBox as CheckBox
@onready var move_up_button := $MoveUpButton as Button
@onready var move_down_button := $MoveDownButton as Button
@onready var name_edit := $NameEdit as LineEdit
@onready var regex_edit := $RegExEdit as LineEdit
@onready var sync_button := $SyncButton as Button
@onready var remove_button := $RemoveButton as Button
@onready var regex_valid := $RegExValid as TextureRect

# private
var _regex := RegEx.new(): get = get_regex

##### NOTIFICATIONS #####

func _ready() -> void:
	if preload("godot_inheritance_dock_plugin.gd").is_part_of_edited_scene(self):
		return

	check.toggled.connect(_on_check_toggled)
	move_up_button.pressed.connect(_on_move_up_button)
	move_down_button.pressed.connect(_on_move_down_button)
	name_edit.text_changed.connect(_on_name_edit_text_changed)
	regex_edit.text_changed.connect(_on_regex_edit_text_changed)
	sync_button.pressed.connect(_on_sync_button_pressed)
	remove_button.pressed.connect(_on_remove_button_pressed)
	_update_regex_valid()

	regex_edit.placeholder_text = PluginTranslation.localize("KEY_REGEX_FILEPATH")
	sync_button.tooltip_text = PluginTranslation.localize("KEY_SYNC_FILTER")

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

func is_valid() -> bool:
	return _regex.is_valid() and _regex.get_pattern()

##### PRIVATE METHODS #####

func _update_regex_valid() -> void:
	regex_valid.texture = REGEX_MAP[is_valid()]

##### CONNECTIONS #####

func _on_check_toggled(p_toggle: bool) -> void:
	emit_signal("checkbox_updated")

func _on_move_up_button() -> void:
	emit_signal("filter_rearranged", self, ButtonEvent.BUTTON_MOVE_UP)

func _on_move_down_button() -> void:
	emit_signal("filter_rearranged", self, ButtonEvent.BUTTON_MOVE_DOWN)

func _on_name_edit_text_changed(p_text: String) -> void:
	emit_signal("name_updated")

func _on_regex_edit_text_changed(p_text: String) -> void:
	_regex.compile(p_text)
	_update_regex_valid()
	emit_signal("regex_updated")

func _on_sync_button_pressed() -> void:
	emit_signal("item_sync_requested", self)

func _on_remove_button_pressed() -> void:
	# Needed to reflect correct children number in filter menu
	# because queue_free() will free it too late.
	hide()

	queue_free()
	emit_signal("item_removed", self)

##### SETTERS AND GETTERS #####

func get_regex() -> RegEx:
	return _regex
