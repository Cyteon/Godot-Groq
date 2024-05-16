@tool
extends PopupMenu

var config = ConfigFile.new()
var err = config.load("res://addons/groq/plugin.cfg")


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_id_pressed(id):
	match id:
		0:
			config.set_value("ai", "model", "gemma-7b-it")
			print("Set AI Model to gemma-7b-it")
		1:
			config.set_value("ai", "model", "llama3-70b-8192")
			print("Set AI Model to llama3-70b-8192")
		2:
			config.set_value("ai", "model", "llama3-8b-8192")
			print("Set AI Model to llama3-8b-8192")
		3:
			config.set_value("ai", "model", "mixtral-8x7b-32768")
			print("Set AI Model to mixtral-8x7b-32768")
	config.save("res://addons/groq/plugin.cfg")
