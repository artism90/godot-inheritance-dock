@tool
extends PopupPanel

## Container for [code]FilterMenuItem[/code] scenes containing one RegEx rule
## per scene.

##### SIGNALS #####

signal filters_updated
signal filters_reloaded
signal item_sync_requested(p_popup: Panel, p_item: FilterMenuItem)

##### CLASSES #####

const FilterMenuItemScene = preload("filter_menu_item.tscn")
const FilterMenuItem = preload("filter_menu_item.gd")
const PluginTranslation = preload("plugin_translation.gd")

##### CONSTANTS #####

const CONFIG_FILE = "godot_inheritance_dock.cfg"

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
@onready var filter_list_label := $PanelContainer/VBoxContainer/HBoxContainer/Label as Label

# private
var _config: ConfigFile: set = set_config

##### NOTIFICATIONS #####

func _ready() -> void:
	if preload("godot_inheritance_dock_plugin.gd").is_part_of_edited_scene(self):
		return

	add_filter_button.pressed.connect(_on_add_filter_button_pressed)
	save_filters_button.pressed.connect(_on_save_filters_button_pressed)
	reload_filters_button.pressed.connect(_on_reload_filters_button_pressed)
	reload_filters_button.disabled = false
	call_deferred("_set_save_disabled", true)

	add_filter_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_ADD_FILTER")
	save_filters_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_SAVE_FILTERS")
	reload_filters_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_RELOAD_FILTERS")
	filter_list_label.text = PluginTranslation.localize("KEY_FILTER_LIST")

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

func add_filter(p_name := "", p_regex_text := "", p_checked := false) -> void:
	var item := FilterMenuItemScene.instantiate() as FilterMenuItem
	filter_vbox.add_child(item)
	_setup_item(item, p_name, p_regex_text, p_checked)

##### PRIVATE METHODS #####

# 1. on check pressed, emit "filters_updated"
# 2. on regex text changed, update icon
func _setup_item(p_item: FilterMenuItem, p_name := "", p_regex_text := "", p_checked := false) -> void:
	if not p_item:
		return

	p_item.name_edit.text = p_name
	# -------------------------------------------------------------------------
	# LineEdit misses text_set signal (currently only in TextEdit implemented)
	# in order to allow setter to invoke _on_regex_edit_text_changed
	# method for initial regex compilation.
	# Keep this band-aid block to remain compatibility throughout all
	# Godot 4 releases.
	p_item._regex.compile(p_regex_text)
	p_item._update_regex_valid()
	# -------------------------------------------------------------------------
	p_item.regex_edit.text = p_regex_text
	p_item.check.button_pressed = p_checked

	# Initial setup shouldn't trigger any callbacks, hence establish them
	# only after the preparation is done and the user can interact with it.
	p_item.checkbox_updated.connect(_update_filters)
	p_item.filter_rearranged.connect(_move_filter)
	p_item.regex_updated.connect(_update_filters)
	p_item.name_updated.connect(_ui_dirtied)
	p_item.item_removed.connect(_on_item_removed)
	p_item.item_sync_requested.connect(_on_item_sync_requested)

func _move_filter(p_item: FilterMenuItem, p_direction: FilterMenuItem.ButtonEvent) -> void:
	filter_vbox.move_child(p_item, p_item.get_index() + p_direction)
	_ui_dirtied()

func _ui_dirtied() -> void:
	size.y = min_size.y
	if save_filters_button:
		_set_save_disabled(false)

func _update_filters() -> void:
	emit_signal("filters_updated")
	_ui_dirtied()

func _get_config_save_filters() -> Array:
	var dict := {}
	if not filter_vbox:
		return filters

	var _filters := []
	for an_item in filter_vbox.get_children():
		if not an_item.name_edit.text:
			continue
		dict[an_item.name_edit.text] = {
			"regex_text": an_item.get_regex().get_pattern(),
			"on": an_item.check.button_pressed
		}
		_filters.append(dict)
		dict = {}

	return _filters

func _set_save_disabled(p_disabled: bool) -> void:
	save_filters_button.self_modulate = save_filters_button.disabled_color if p_disabled else save_filters_button.natural_color
	save_filters_button.disabled = p_disabled

##### CONNECTIONS #####

func _on_add_filter_button_pressed() -> void:
	add_filter()
	_update_filters()

func _on_save_filters_button_pressed() -> void:
	if not _config:
		return

	_config.set_value("filters", type+"_filters", _get_config_save_filters())
	_config.save(get_script().get_path().get_base_dir().path_join(CONFIG_FILE))
	_set_save_disabled(true)

func _on_reload_filters_button_pressed() -> void:
	if not _config:
		print("WARNING: ({0}::_on_reload_filters_button_pressed) Cannot reload filters! Reason: invalid config reference".format([get_script().get_path()]))
		return

	# TODO: Refactor.
	var new_filters_array: Array = _config.get_value("filters", type+"_filters")
	var new_filters := {}
	for a_filter: Dictionary in new_filters_array:
		new_filters.merge(a_filter)

	set_filters(new_filters)
	_set_save_disabled(true)

func _on_item_removed(p_item: FilterMenuItem) -> void:
	_ui_dirtied()

func _on_item_sync_requested(p_item: FilterMenuItem) -> void:
	emit_signal("item_sync_requested", self, p_item)

##### SETTERS AND GETTERS #####

func set_config(p_config: ConfigFile) -> void:
	_config = p_config
	if _config.has_section_key("filters", type+"_filters"):
		# TODO: Refactor.
		var new_filters_array: Array = _config.get_value("filters", type+"_filters")
		var new_filters := {}
		for a_filter: Dictionary in new_filters_array:
			new_filters.merge(a_filter)
		set_filters(new_filters)

func set_filters(p_filters: Variant) -> void:
	if not filter_vbox:
		return

	for a_child in filter_vbox.get_children():
		a_child.free()

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
