@tool
extends PopupPanel

## Container for [code]FilterMenuItem[/code] scenes containing one RegEx rule
## per scene.

##### CLASSES #####

##### SIGNALS #####

signal filters_updated
signal item_sync_requested(p_popup, p_item)

##### CONSTANTS #####

const FilterMenuItemScene = preload("filter_menu_item.tscn")
const FilterMenuItem = preload("filter_menu_item.gd")

const CONFIG_PATH = "res://addons/godot_inheritance_dock/godot_inheritance_dock.cfg"

##### EXPORTS #####

##### MEMBERS #####

# public
var filters := []: get = get_filters, set = set_filters
var type := ""

# public onready
@onready var add_filter_button := $PanelContainer/VBoxContainer/HBoxContainer/AddFilterButton as Button
@onready var save_filters_button := $PanelContainer/VBoxContainer/HBoxContainer/SaveFiltersButton as Button
@onready var reload_filters_button := $PanelContainer/VBoxContainer/HBoxContainer/ReloadFiltersButton as Button
@onready var filter_vbox := $PanelContainer/VBoxContainer/FilterVbox as VBoxContainer

# private
var _config: ConfigFile = null: set = set_config

##### NOTIFICATIONS #####

func _ready() -> void:
	add_filter_button.pressed.connect(_on_add_filter_button_pressed)
	save_filters_button.pressed.connect(_on_save_filters_button_pressed)
	reload_filters_button.pressed.connect(_on_reload_filters_button_pressed)
	reload_filters_button.disabled = false
	call_deferred("_set_save_disabled", true)

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

func add_filter(p_name := "", p_regex_text := "", p_checked := false) -> void:
	var item := FilterMenuItemScene.instantiate()
	filter_vbox.add_child(item)
	_setup_item(item, p_name, p_regex_text, p_checked)

##### PRIVATE METHODS #####

# 1. on check pressed, emit "filters_updated"
# 2. on regex text changed, update icon
func _setup_item(p_item: FilterMenuItem, p_name := "", p_regex_text := "", p_checked := false) -> void:
	if not p_item:
		return

	p_item.checkbox_updated.connect(_update_filters)
	p_item.regex_updated.connect(_update_filters)
	p_item.name_updated.connect(_ui_dirtied)
	p_item.item_removed.connect(_ui_dirtied)
	p_item.item_sync_requested.connect(_on_item_sync_requested)
	p_item.name_edit.text = p_name
	p_item.regex_edit.text = p_regex_text
	p_item.check.button_pressed = p_checked

func _ui_dirtied() -> void:
	if save_filters_button:
		_set_save_disabled(false)

func _update_filters() -> void:
	emit_signal("filters_updated")
	_ui_dirtied()

func _get_config_save_filters_dict() -> Variant:
	var dict := {}
	if not filter_vbox:
		return filters

	for an_item in filter_vbox.get_children():
		if not an_item.name_edit.text:
			continue
		dict[an_item.name_edit.text] = {
			"regex_text": an_item.get_regex().get_pattern(),
			"on": an_item.check.button_pressed
		}
	return dict

func _set_save_disabled(p_disabled: bool) -> void:
	save_filters_button.self_modulate = save_filters_button.disabled_color if p_disabled else save_filters_button.natural_color
	save_filters_button.disabled = p_disabled

##### CONNECTIONS #####

func _on_add_filter_button_pressed():
	add_filter()
	_update_filters()

func _on_save_filters_button_pressed() -> void:
	if not _config:
		return

	_config.set_value("filters", type+"_filters", _get_config_save_filters_dict())
	_config.save(CONFIG_PATH)
	_set_save_disabled(true)

func _on_reload_filters_button_pressed() -> void:
	if not _config:
		print("WARNING: ({0}::_on_reload_filters_button_pressed) Cannot reload filters! Reason: invalid config reference".format([get_script().get_path()]))
		return

	var new_filters: Dictionary = _config.get_value("filters", type+"_filters")
	set_filters(new_filters)
	_set_save_disabled(true)

func _on_item_sync_requested(p_item: FilterMenuItem) -> void:
	emit_signal("item_sync_requested", self, p_item)

##### SETTERS AND GETTERS #####

func set_config(p_config: ConfigFile) -> void:
	_config = p_config
	if _config.has_section_key("filters", type+"_filters"):
		set_filters(_config.get_value("filters", type+"_filters"))

func set_filters(p_filters: Variant) -> void:
	if not filter_vbox:
		return

	for a_child in filter_vbox.get_children():
		a_child.queue_free()

	for a_name in p_filters:
		var regex_text: String = p_filters[a_name]["regex_text"]
		var checked: bool = p_filters[a_name]["on"]
		add_filter(a_name, regex_text, checked)
	_update_filters()

func get_filters() -> Array:
	var filters: Array[RegEx] = []
	if not filter_vbox:
		return filters

	for an_item in filter_vbox.get_children():
		if an_item.check.button_pressed and an_item.is_valid():
			filters.append(an_item.get_regex())
	return filters
