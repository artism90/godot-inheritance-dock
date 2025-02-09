@tool
extends EditorPlugin

## The Godot Inheritance Dock plugin class.

##### SIGNALS #####

##### CLASSES #####

const InheritanceDock = preload("inheritance_dock.gd")
const PluginTranslation = preload("plugin_translation.gd")

##### CONSTANTS #####

## The current Godot scene header for inherited scenes. Should this change
## internally, this data can be retrieved by manually creating an inherited
## scene and copypasting its contents to this constant.
const SCENE_HEADER = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="{0}" id="1"]

[node name="{1}" instance=ExtResource("1")]"""

##### EXPORTS #####

##### MEMBERS #####

# public
var dock: InheritanceDock
var selected = null
var scene_file_dialog := EditorFileDialog.new()
var res_file_dialog := EditorFileDialog.new()

# public onready

# private
var _scene_path := "" # for use in extending scenes
var _res_script_path := "" # for use in assigning a script or type to generated .(t)res files
var _undo_redo: EditorUndoRedoManager

##### NOTIFICATIONS #####

func _enter_tree() -> void:
	dock = preload("inheritance_dock.tscn").instantiate() as InheritanceDock
	dock.set_name(PluginTranslation.localize("KEY_TITLE"))
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)

	dock.add_script_request.connect(_on_add_script_request)
	dock.extend_script_request.connect(_on_extend_script_request)
	dock.instance_script_request.connect(_on_instance_script_request)
	dock.edit_script_request.connect(_on_edit_script_request)
	dock.extend_scene_request.connect(_on_extend_scene_request)
	dock.instance_scene_request.connect(_on_instance_scene_request)
	dock.edit_scene_request.connect(_on_edit_scene_request)
	dock.new_res_request.connect(_on_new_res_request)
	dock.edit_res_request.connect(_on_edit_res_request)
	dock.file_selected.connect(_on_file_selected)

	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(dock._scan_files)

	get_editor_interface().get_base_control().add_child(scene_file_dialog)
	scene_file_dialog.add_filter("*.tscn,*.scn; Scenes")
	scene_file_dialog.mode = Window.MODE_WINDOWED
	scene_file_dialog.get_ok_button().pressed.connect(_on_save_scene_pressed)
	scene_file_dialog.get_line_edit().text_submitted.connect(_on_save_scene_pressed)
	get_editor_interface().get_base_control().add_child(res_file_dialog)
	res_file_dialog.add_filter("*.tres,*.res; Resources")
	res_file_dialog.mode = Window.MODE_WINDOWED
	res_file_dialog.get_ok_button().pressed.connect(_on_res_file_pressed)

	_undo_redo = get_undo_redo()

func _enable_plugin() -> void:
	# Initial file tree creation, later through filesystem_changed signal
	get_editor_interface().get_resource_filesystem().scan()

func _exit_tree() -> void:
	scene_file_dialog.free()
	res_file_dialog.free()
	remove_control_from_docks(dock)
	dock.free()

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

static func is_part_of_edited_scene(node: Node) -> bool:
	return Engine.is_editor_hint() and node.is_inside_tree() and node.get_tree().get_edited_scene_root() and \
			(node.get_tree().get_edited_scene_root() == node or node.get_tree().get_edited_scene_root().is_ancestor_of(node))

##### PRIVATE METHODS #####

func _make_extended_scene() -> void:
	var path := scene_file_dialog.current_path
	var f := FileAccess.open(path, FileAccess.WRITE_READ)
	if f.get_error() != OK:
		return

	var type: Node = load(_scene_path).instantiate()
	if type is Node2D or type is Control:
		get_editor_interface().set_main_screen_editor("2D")
	elif type is Node3D:
		get_editor_interface().set_main_screen_editor("3D")

	var root_name := scene_file_dialog.current_file.get_basename().to_pascal_case()
	f.store_string(SCENE_HEADER.format([_scene_path, root_name]))
	f.close()

	get_editor_interface().open_scene_from_path(path)
	# Invoke saving to allow the engine adding internal data (e.g. Godot 4 UIDs)
	# which can't be retrieved/generated from the plugin itself.
	get_editor_interface().save_scene()
	# Make visible in file system dock.
	get_editor_interface().select_file(path)

func _make_res_file() -> void:
	var path := res_file_dialog.get_current_file()
	var f := FileAccess.open(path, FileAccess.WRITE_READ)
	if f.get_error() != OK:
		return

	var script: Script = null
	var res_type: Variant = null
	if _res_script_path.find(".", 0) != -1:
		script = load(_res_script_path) as Script
		res_type = script.get_instance_base_type() if script else &"Resource"
	else:
		script = null
		res_type = _res_script_path
	f.store_string("[gd_resource type=\""+res_type+"\" format=3]\n\n[resource]\n\n")
	f.close()
	var res := load(path)
	res.set_script(script)
	get_editor_interface().edit_resource(script)
	get_editor_interface().edit_resource(res)

func _is_asset(p_path: String) -> bool:
	return p_path.find(".", 0) != -1 and p_path[p_path.length() - 1] != "/"

##### CONNECTIONS #####

func _on_add_script_request(p_script_path: String) -> void:
	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	var script := load(p_script_path)
	if not script or not ClassDB.can_instantiate(script.get_instance_base_type()):
		return

	_undo_redo.create_action(PluginTranslation.localize("KEY_UNDO_REDO_ADD_SCRIPT_UNDER_NODE"), UndoRedo.MERGE_ALL)
	for a_node in nodes:
		var a_script: Script = a_node.get_script()
		_undo_redo.add_do_method(a_node, "set_script", script)
		_undo_redo.add_undo_method(a_node, "set_script", a_script)
	_undo_redo.commit_action()

func _on_extend_script_request(p_script_path: String) -> void:
	var script := load(p_script_path)
	if not script:
		return

	var base_path := "\""+p_script_path+"\""
	var class_path := p_script_path.get_base_dir().path_join("new_class")
	get_editor_interface().get_script_editor().open_script_create_dialog(base_path, class_path)

func _on_instance_script_request(p_script_path: String) -> void:
	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	var script := load(p_script_path)
	if not script or not ClassDB.can_instantiate(script.get_instance_base_type()):
		return

	_undo_redo.create_action(PluginTranslation.localize("KEY_UNDO_REDO_INSTANCIATE_SCRIPT_UNDER_NODE"), UndoRedo.MERGE_ALL)
	if not nodes.is_empty():
		for a_selected_node in get_editor_interface().get_selection().get_selected_nodes():
			_undo_redo.add_undo_method(get_editor_interface().get_selection(), "add_node", a_selected_node)
		_undo_redo.add_do_method(get_editor_interface().get_selection(), "clear")

	for a_node in nodes:
		var new_node := script.new() as Script
		_undo_redo.add_do_method(a_node, "add_child", new_node)
		_undo_redo.add_do_method(new_node, "set_owner", get_editor_interface().get_edited_scene_root())
		_undo_redo.add_do_method(get_editor_interface().get_selection(), "add_node", new_node)
		_undo_redo.add_undo_method(new_node, "queue_free")
	_undo_redo.commit_action()

func _on_edit_script_request(p_script_path: String) -> void:
	if not _is_asset(p_script_path):
		return

	var script := load(p_script_path)
	get_editor_interface().edit_resource(script)

func _on_extend_scene_request(p_scene_path: String) -> void:
	_scene_path = p_scene_path # make the path quickly accessible to connected functions
	scene_file_dialog.current_path = ""
	scene_file_dialog.current_dir = _scene_path.get_base_dir()
	scene_file_dialog.popup_centered_ratio()

func _on_instance_scene_request(p_scene_path: String) -> void:
	if get_editor_interface().get_edited_scene_root().get_scene_file_path() == p_scene_path:
		var err_dialog := AcceptDialog.new()
		get_editor_interface().get_base_control().add_child(err_dialog)
		err_dialog.get_label().text = "You cannot instance a scene within itself!"
		err_dialog.popup_centered_clamped()
		return

	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	var scene := load(p_scene_path)
	if not scene:
		return

	_undo_redo.create_action(PluginTranslation.localize("KEY_UNDO_REDO_INSTANCIATE_SCENE_UNDER_NODE"), UndoRedo.MERGE_ALL)
	if not nodes.is_empty():
		for a_selected_node in get_editor_interface().get_selection().get_selected_nodes():
			_undo_redo.add_undo_method(get_editor_interface().get_selection(), "add_node", a_selected_node)
		_undo_redo.add_do_method(get_editor_interface().get_selection(), "clear")

	for a_node in nodes:
		var new_node = scene.instantiate()
		_undo_redo.add_do_method(a_node, "add_child", new_node)
		_undo_redo.add_do_method(new_node, "set_owner", get_editor_interface().get_edited_scene_root())
		_undo_redo.add_do_method(get_editor_interface().get_selection(), "add_node", new_node)
		_undo_redo.add_undo_method(new_node, "queue_free")
	_undo_redo.commit_action()

func _on_edit_scene_request(p_scene_path: String) -> void:
	if not _is_asset(p_scene_path):
		return

	get_editor_interface().open_scene_from_path(p_scene_path)

func _on_save_scene_pressed(p_path: String = "") -> void:
	_make_extended_scene()

func _on_res_file_pressed() -> void:
	_make_res_file()

func _on_new_res_request(p_script_path: String) -> void:
	_res_script_path = p_script_path # make the path quickly accessible to connection functions
	res_file_dialog.popup_centered_ratio()

func _on_edit_res_request(p_res_path: String) -> void:
	if not _is_asset(p_res_path):
		return

	var res := load(p_res_path)
	get_editor_interface().edit_resource(res)

func _on_file_selected(p_file: String) -> void:
	# This will only select the file.
	# Hidden FileSystemDock has to be opened explicitly.
	get_editor_interface().select_file(p_file)

	# Other docks will leak into FileSystemDock if sharing the
	# same panel and are not explicitly hidden.
	var file_system_dock := get_editor_interface().get_file_system_dock()
	var panel_with_file_system_dock := file_system_dock.get_parent()
	for child in panel_with_file_system_dock.get_children():
		if child is FileSystemDock:
			child.show()
		else:
			child.hide()

	# FIXME
	# Currently, panel tab won't update when panel itself changes to
	# FileSystemDock. As of 4.2, it appears to be no mechanism available for
	# switching docks. Verify future versions for a solution.

##### SETTERS AND GETTERS #####
