@tool
extends PanelContainer

## The main interface.

##### SIGNALS #####

signal load_failed
signal add_script_request(p_script_path: String)
signal extend_script_request(p_script_path: String)
signal instance_script_request(p_script_path: String)
signal edit_script_request(p_script_path: String)
signal extend_scene_request(p_scene_path: String)
signal instance_scene_request(p_scene_path: String)
signal edit_scene_request(p_scene_path: String)
signal new_res_request(p_script_path: String)
signal edit_res_request(p_res_path: String)
signal file_selected(p_file: String)

##### CLASSES #####

##### CONSTANTS #####

enum Mode {SCENE_MODE = 0, SCRIPT_MODE = 1, RES_MODE = 2}
enum Caches {CACHE_NONE = 0, CACHE_SCENE = 1, CACHE_SCRIPT = 2, CACHE_RES = 4}

const Util = preload("res_utility.gd")
const FilterMenuScene = preload("filter_menu.tscn")
const FilterMenu = preload("filter_menu.gd")
const FilterMenuItem = preload("filter_menu_item.gd")
const PluginTranslation = preload("plugin_translation.gd")

const TITLE = "Inheritance"
const SCRIPT_ICON = preload("icons/icon_script.svg")
const RES_ICON = preload("icons/icon_resource.svg")
const SCENE_ICON = preload("icons/icon_scene.svg")
const BASETYPE_ICON = preload("icons/icon_basetype.svg")
const FOLDER_ICON = preload("icons/icon_folder.svg")

const CONFIG_FILE = "godot_inheritance_dock.cfg"

const ICONS = {
	Mode.RES_MODE: RES_ICON,
	Mode.SCRIPT_MODE: SCRIPT_ICON,
	Mode.SCENE_MODE: SCENE_ICON
}
const CACHE_MAP = {
	Mode.RES_MODE: Caches.CACHE_RES,
	Mode.SCENE_MODE: Caches.CACHE_SCENE,
	Mode.SCRIPT_MODE: Caches.CACHE_SCRIPT
}

##### EXPORTS #####

##### MEMBERS #####

# public
var filters := []
var files := []
var selected = null
var filter_popup: FilterMenu
var tree: Tree
var tree_dict := {}

# public onready
@onready var scene_tab_button := $VBoxContainer/TypeContainer/Scenes as Button
@onready var script_tab_button := $VBoxContainer/TypeContainer/Scripts as Button
@onready var resource_tab_button := $VBoxContainer/TypeContainer/Resources as Button
@onready var filter_menu_button := $VBoxContainer/HBoxContainer/FilterContainer/FilterMenuButton as Button
@onready var scene_tree := $VBoxContainer/TabContainer/Scenes as Tree
@onready var script_tree := $VBoxContainer/TabContainer/Scripts as Tree
@onready var resource_tree := $VBoxContainer/TabContainer/Resources as Tree
@onready var search_edit := $VBoxContainer/SearchContainer/LineEdit as LineEdit
@onready var new_file_button := $VBoxContainer/HBoxContainer/ToolContainer/NewFileButton as Button
@onready var add_script_button := $VBoxContainer/HBoxContainer/ToolContainer/AddScriptButton as Button
@onready var extend_button := $VBoxContainer/HBoxContainer/ToolContainer/ExtendButton as Button
@onready var instance_button := $VBoxContainer/HBoxContainer/ToolContainer/InstanceButton as Button
@onready var find_button := $VBoxContainer/HBoxContainer/ToolContainer/FindButton as Button
@onready var class_filter_edit := $VBoxContainer/HBoxContainer/FilterContainer/ClassFilterEdit as LineEdit
@onready var tab := $VBoxContainer/TabContainer as TabContainer

# private
var _config := ConfigFile.new()
var _config_loaded := false
var _scene_dict := {}
var _script_dict := {}
var _resource_dict := {}
var _scene_collapsed_set := {}
var _script_collapsed_set := {}
var _resource_collapsed_set := {}
var _collapsed_set := {}
var _sort := Util.SORT_SCENE_INHERITANCE
var _mode := Mode.SCENE_MODE: set = set_mode
var _scene_filter_popup: FilterMenu
var _script_filter_popup: FilterMenu
var _resource_filter_popup: FilterMenu
var _filter_popups: Array[FilterMenu]
var _search_filter := "": set = set_search_filter
var _class_filter := "": set = set_class_filter
var _ready_done := false
var _cache_flags := Caches.CACHE_NONE

##### NOTIFICATIONS #####

func _init() -> void:
	_init_config()
	if not _config_loaded:
		emit_signal("load_failed")

func _ready() -> void:
	if preload("godot_inheritance_dock_plugin.gd").is_part_of_edited_scene(self) or not _config_loaded:
		return

	# Connections
	search_edit.text_changed.connect(_on_search_text_changed)
	scene_tab_button.pressed.connect(_on_scene_tab_button_pressed)
	script_tab_button.pressed.connect(_on_script_tab_button_pressed)
	resource_tab_button.pressed.connect(_on_resource_tab_button_pressed)
	new_file_button.pressed.connect(_on_new_file_button_pressed)
	add_script_button.pressed.connect(_on_add_script_button_pressed)
	extend_button.pressed.connect(_on_extend_button_pressed)
	instance_button.pressed.connect(_on_instance_button_pressed)
	find_button.pressed.connect(_on_find_button_pressed)
	filter_menu_button.pressed.connect(_on_filter_menu_button_pressed)
	class_filter_edit.text_changed.connect(_on_class_filter_edit_text_changed)
	scene_tree.item_collapsed.connect(_on_item_collapsed)
	script_tree.item_collapsed.connect(_on_item_collapsed)
	resource_tree.item_collapsed.connect(_on_item_collapsed)
	scene_tree.item_activated.connect(_on_item_activated)
	script_tree.item_activated.connect(_on_item_activated)
	resource_tree.item_activated.connect(_on_item_activated)

	# Filters Initialization
	_scene_filter_popup = FilterMenuScene.instantiate() as FilterMenu
	add_child(_scene_filter_popup)
	_scene_filter_popup.type = "scene"
	_scene_filter_popup.filters_updated.connect(_update_filters)
	_scene_filter_popup.item_sync_requested.connect(_on_item_sync_requested)
	_scene_filter_popup.set_config(_config)
	_filter_popups.append(_scene_filter_popup)

	_script_filter_popup = FilterMenuScene.instantiate() as FilterMenu
	add_child(_script_filter_popup)
	_script_filter_popup.type = "script"
	_script_filter_popup.filters_updated.connect(_update_filters)
	_script_filter_popup.item_sync_requested.connect(_on_item_sync_requested)
	_script_filter_popup.set_config(_config)
	_filter_popups.append(_script_filter_popup)

	_resource_filter_popup = FilterMenuScene.instantiate() as FilterMenu
	add_child(_resource_filter_popup)
	_resource_filter_popup.type = "resource"
	_resource_filter_popup.filters_updated.connect(_update_filters)
	_resource_filter_popup.item_sync_requested.connect(_on_item_sync_requested)
	_resource_filter_popup.set_config(_config)
	_filter_popups.append(_resource_filter_popup)

	# UI Initialization
	scene_tab_button.text = PluginTranslation.localize("KEY_SCENES")
	script_tab_button.text = PluginTranslation.localize("KEY_SCRIPTS")
	resource_tab_button.text = PluginTranslation.localize("KEY_RESOURCES")

	extend_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_EXTEND_TYPE")
	instance_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_INSTANCIATE_NODE")
	find_button.tooltip_text = PluginTranslation.localize("KEY_TOOLTIP_FIND_IN_FILE_SYSTEM")

	class_filter_edit.placeholder_text = PluginTranslation.localize("KEY_FILTER_BY_CLASS")
	set_mode(_mode)

	_ready_done = true

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

##### PRIVATE METHODS #####

func _init_config() -> void:
	var err := _config.load((get_script().get_path().get_base_dir().path_join(CONFIG_FILE)))
	if err != OK:
		print("WARNING: ({0}::_init_config) {1} failed to load!".format([get_script().get_path(), CONFIG_FILE]))
	_config_loaded = true

	if _config.has_section_key("window", "custom_minimum_size"):
		custom_minimum_size = _config.get_value("window", "custom_minimum_size")
	else:
		custom_minimum_size = Vector2(0, 50)

func _init_files() -> void:
	_scene_dict = Util.build_file_tree_dict(Util.SORT_SCENE_INHERITANCE)
	_script_dict = Util.build_file_tree_dict(Util.SORT_SCRIPT_INHERITANCE)
	_resource_dict = Util.build_file_tree_dict(Util.SORT_RES_INHERITANCE)
	_cache_flags = Caches.CACHE_NONE
	match _mode:
		Mode.SCRIPT_MODE:
			tree = script_tree
			tree_dict = _script_dict
		Mode.RES_MODE:
			tree = resource_tree
			tree_dict = _resource_dict
		Mode.SCENE_MODE, _:
			tree = scene_tree
			tree_dict = _scene_dict
	_cache_flags |= CACHE_MAP[_mode]
	_build_tree_from_tree_dict(tree, tree_dict)

func _mode_to_name() -> String:
	match _mode:
		Mode.SCRIPT_MODE: return "script"
		Mode.RES_MODE: return "resource"
		Mode.SCENE_MODE, _: return "scene"

func _build_tree_from_tree_dict(p_tree: Tree, p_tree_dict: Dictionary) -> void:
	if not p_tree or not p_tree_dict or not _ready_done:
		return

	p_tree.clear()
	p_tree.set_hide_root(true)
	p_tree.set_select_mode(Tree.SELECT_SINGLE)
	var root := p_tree.create_item()

	var file := p_tree_dict
	var item := root
	var file_list := [file]
	var item_list := [item]

	while not file_list.is_empty():
		file = file_list.back()
		item = item_list.back()
		var count := len(file["children"])

		for a_filepath in file["children"]:
			var child := file["children"][a_filepath] as Dictionary
			var do_create := true

			var link_data: String = a_filepath
			var is_directory: bool = a_filepath.find("/", a_filepath.length() - 1) != -1
			if is_directory:
				link_data = ("" if a_filepath == "res://" else "res://addons") + a_filepath

			if child["children"].is_empty():
				if _search_filter and link_data.find(_search_filter) == -1:
					do_create = false

				if _class_filter and not is_directory:
					var res := load(a_filepath)
					var type := ""

					if res is PackedScene:
						var state := res.get_state() as SceneState
						type = state.get_node_type(0)
					elif res is Script:
						type = res.get_instance_base_type()
					elif res is Resource:
						type = res.get_class()

					if type != _class_filter:
						do_create = false

				if filter_popup:
					for a_regex in filter_popup.get_filters():
						if not a_regex.search(link_data):
							do_create = false
							break

			if do_create:
				var new_item := p_tree.create_item(item)
				new_item.set_selectable(0, true)
				new_item.set_editable(0, false)
				if a_filepath in _collapsed_set:
					new_item.set_collapsed(true)

				var img = null

				if a_filepath.find("/", a_filepath.length() - 1) != -1:
					img = FOLDER_ICON
					new_item.set_text(0, a_filepath)
					new_item.set_metadata(0, link_data)
					new_item.set_tooltip_text(0, link_data)
				else:
					new_item.set_text(0, a_filepath.get_file())
					new_item.set_metadata(0, a_filepath)
					new_item.set_tooltip_text(0, a_filepath)

				match _mode:
					Mode.RES_MODE:
						if not img:
							var ext: String = a_filepath.get_extension()
							if a_filepath.find(".", 0) == -1:
								ext = ""
							if not ext:
								img = BASETYPE_ICON
							elif ext.find("res", 0) != -1:
								img = RES_ICON
							else:
								img = SCRIPT_ICON
					Mode.SCENE_MODE, Mode.SCRIPT_MODE, _:
						if not img:
							img = ICONS[_mode]
				new_item.set_icon(0, img)

				file_list.push_front(child)
				item_list.push_front(new_item)
			count -= 1
			if not count and item.get_parent() and not item.get_children():
				item.get_parent().remove_child(item)

		if not file_list.is_empty():
			file_list.pop_back()
			item_list.pop_back()

##### CONNECTIONS #####

func _on_scene_tab_button_pressed() -> void:
	set_mode(Mode.SCENE_MODE)

func _on_script_tab_button_pressed() -> void:
	set_mode(Mode.SCRIPT_MODE)

func _on_resource_tab_button_pressed() -> void:
	set_mode(Mode.RES_MODE)

func _on_search_text_changed(p_text: String) -> void:
	set_search_filter(p_text)

func _on_class_filter_edit_text_changed(p_text: String) -> void:
	set_class_filter(p_text)

func _on_new_file_button_pressed() -> void:
	if resource_tree and resource_tree.get_selected():
		var path: String = resource_tree.get_selected().get_metadata(0)
		var img := resource_tree.get_selected().get_icon(0)
		if img == BASETYPE_ICON or img == SCRIPT_ICON: # not a resource file
			emit_signal("new_res_request", path)

func _on_add_script_button_pressed() -> void:
	if script_tree and script_tree.get_selected():
		emit_signal("add_script_request", script_tree.get_selected().get_metadata(0))

func _on_extend_button_pressed() -> void:
	if tree and tree.get_selected():
		emit_signal("extend_"+_mode_to_name()+"_request", tree.get_selected().get_metadata(0))

func _on_instance_button_pressed() -> void:
	if tree and tree.get_selected():
		emit_signal("instance_"+_mode_to_name()+"_request", tree.get_selected().get_metadata(0))

func _on_find_button_pressed() -> void:
	if tree and tree.get_selected():
		emit_signal("file_selected", tree.get_selected().get_metadata(0))

func _on_file_selected(p_file: String) -> void:
	emit_signal("file_selected", p_file)

func _on_filter_menu_button_pressed() -> void:
	if not filter_popup:
		return

	filter_popup.visible = !filter_popup.visible
	if filter_popup.visible:
		var x := Vector2(get_tree().get_root().size.x, 0) / 2
		var pos := filter_menu_button.get_global_position()
		var side := 1 if pos > x else 0
		filter_popup.set_position(filter_menu_button.get_screen_position() + Vector2(side * -400, 50))

func _update_filters() -> void:
	_build_tree_from_tree_dict(tree, tree_dict)

func _scan_files() -> void:
	if scene_tree:
		scene_tree.clear()
	if script_tree:
		script_tree.clear()
	if resource_tree:
		resource_tree.clear()
	_init_files()

func _on_item_collapsed(p_item: TreeItem) -> void:
	if not p_item.is_collapsed() and _collapsed_set.has(p_item.get_metadata(0)):
		_collapsed_set.erase(p_item.get_metadata(0))
	else:
		_collapsed_set[p_item.get_metadata(0)] = null

func _on_item_activated() -> void:
	if not tree:
		print("WARNING: ({0}::_on_item_activated) 'tree' is Nil!".format([get_script().get_path()]))
		return
	var item := tree.get_selected()
	if item:
		match _mode:
			Mode.SCENE_MODE, Mode.SCRIPT_MODE:
				emit_signal("edit_"+_mode_to_name()+"_request", item.get_metadata(0))
			Mode.RES_MODE:
				var meta: Variant = item.get_metadata(0)
				var ext: Variant = meta.get_extension()
				if ext:
					var is_res = ext.find("res", 0) != -1
					emit_signal("edit_"+ ("res" if is_res else "script") +"_request", meta)
				elif meta.find(".", 0) == -1:
					pass # TODO: It's an in-engine type. Open class API

func _on_item_sync_requested(p_popup: FilterMenu, p_item: FilterMenuItem) -> void:
	var filter_name := p_item.name_edit.text
	var checked := p_item.check.button_pressed
	var regex_text := p_item.regex_edit.text
	for a_popup in _filter_popups:
		if a_popup != p_popup:
			var found := false
			for an_item in a_popup.filter_vbox.get_children():
				if an_item.name_edit.text == filter_name:
					# ---------------------------------------------------------
					# LineEdit misses text_set signal (currently only in
					# TextEdit implemented) in order to allow setter to
					# invoke _on_regex_edit_text_changed method for
					# initial regex compilation.
					# Keep this band-aid block to remain compatibility
					# throughout all Godot 4 releases.
					an_item._regex.compile(regex_text)
					an_item._update_regex_valid()
					# ---------------------------------------------------------
					an_item.regex_edit.text = regex_text
					an_item.check.button_pressed = checked
					found = true
					break
			if not found:
				a_popup.add_filter(filter_name, regex_text, checked)

##### SETTERS AND GETTERS #####

func set_mode(p_mode: Mode) -> void:
	_mode = p_mode
	tab.current_tab = p_mode
	if filter_popup:
		filter_popup.visible = false
	match p_mode:
		Mode.SCRIPT_MODE:
			filter_popup = _script_filter_popup
			_sort = Util.SORT_SCRIPT_INHERITANCE
			new_file_button.disabled = true
			new_file_button.self_modulate = new_file_button.disabled_color
			add_script_button.disabled = false
			add_script_button.self_modulate = add_script_button.natural_color
			extend_button.disabled = false
			extend_button.self_modulate = extend_button.natural_color
			instance_button.disabled = false
			instance_button.self_modulate = extend_button.natural_color
			tree = script_tree
			tree_dict = _script_dict
			_collapsed_set = _script_collapsed_set
		Mode.RES_MODE:
			filter_popup = _resource_filter_popup
			_sort = Util.SORT_RES_INHERITANCE
			new_file_button.disabled = false
			new_file_button.self_modulate = new_file_button.natural_color
			add_script_button.disabled = true
			add_script_button.self_modulate = add_script_button.disabled_color
			extend_button.disabled = true
			extend_button.self_modulate = extend_button.disabled_color
			instance_button.disabled = true
			instance_button.self_modulate = extend_button.disabled_color
			tree = resource_tree
			tree_dict = _resource_dict
			_collapsed_set = _resource_collapsed_set
		Mode.SCENE_MODE, _:
			filter_popup = _scene_filter_popup
			_sort = Util.SORT_SCENE_INHERITANCE
			new_file_button.disabled = true
			new_file_button.self_modulate = new_file_button.disabled_color
			add_script_button.disabled = true
			add_script_button.self_modulate = add_script_button.disabled_color
			extend_button.disabled = false
			extend_button.self_modulate = extend_button.natural_color
			instance_button.disabled = false
			instance_button.self_modulate = extend_button.natural_color
			tree = scene_tree
			tree_dict = _scene_dict
			_collapsed_set = _scene_collapsed_set
	search_edit.placeholder_text = PluginTranslation.localize("KEY_FILTER_" + _mode_to_name().to_upper() + "S")
	if not (_cache_flags & CACHE_MAP[_mode]):
		_build_tree_from_tree_dict(tree, tree_dict)
		_cache_flags |= CACHE_MAP[_mode]

func set_search_filter(p_value: String) -> void:
	_search_filter = p_value
	_build_tree_from_tree_dict(tree, tree_dict)

func set_class_filter(p_value: String) -> void:
	_class_filter = p_value
	_build_tree_from_tree_dict(tree, tree_dict)
