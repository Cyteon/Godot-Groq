@tool
extends EditorPlugin

var dock
var submenu

func _enter_tree():
	dock = preload("res://addons/groq/UI/GroqDock.tscn").instantiate()
	submenu = preload("res://addons/groq/UI/AiModelSubmenu.tscn").instantiate()
	
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	
	add_tool_submenu_item("Set AI Model", submenu)

func _exit_tree():
	remove_control_from_docks(dock)
	remove_tool_menu_item("Set AI Model")
	
	dock.free()
	#submenu.free()
