@tool
extends Control

@onready var MessageEdit = $MessagingBox/MessageEdit
@onready var HTTP = $HTTPRequest
@onready var ChatLogVbox = $ChatLogContainer/ChatLogVbox

const API_URL = "https://api.groq.com/openai/v1/chat/completions"
var model

var messageLog = []

var waitingForApiKey = false

# Called when the node enters the scene tree for the first time.
func _ready():
	HTTP.request_completed.connect(_on_request_completed)
	
func get_home_directory():
	var home = null
	for env in ["USERPROFILE", "HOME"]:
		home = OS.get_environment(env)
		if home:
			if OS.has_feature("windows"):
				home = home.replace('\\', '/')
			return home

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func add_chat_label(text):
	var l = RichTextLabel.new()
	l.fit_content = true
	l.selection_enabled = true
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	ChatLogVbox.add_child(l)
	
	await $ChatLogContainer.get_v_scroll_bar().changed
	$ChatLogContainer.scroll_vertical =  $ChatLogContainer.get_v_scroll_bar().max_value
	

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if not json.has("choices"):
		match json.error.code:
			"invalid_api_key":
				waitingForApiKey = true
				add_chat_label("Invalid API Key, enter again")
				pass
		return
	
	add_chat_label("AI: " + json.choices[0].message.content)
	
	messageLog.append(
		{
			"role": "assistant", 
			"content": json.choices[0].message.content
		}
	)

func query_ai(prompt):
	var config = ConfigFile.new()
	var err = config.load("res://addons/groq/plugin.cfg")
	model = config.get_value("ai", "model")
	
	config = ConfigFile.new()
	err = config.load(get_home_directory() + "/.godot-groq.cfg")
	
	add_chat_label("You: " + prompt)
	
	if waitingForApiKey:
		config.set_value("ai", "api_key", prompt)
		config.save(get_home_directory() + "/.godot-groq.cfg")
		waitingForApiKey = false
		
		return
	
	var api_key = config.get_value("ai", "api_key", "404")
	
	if api_key == "404":
		add_chat_label("Send your API key")
		waitingForApiKey = true
		return
	
	var messages = {
			"messages": messageLog,
			"model": model
		}
	
	messages.messages.append_array([
		{
			"role": "system",
			"content": """
				You are an Godot 4 assistant, your primary coding language is GDScript, but godot also supports C#.
				- You NOT allowed to use backticks, you have to use one newline for each backtick
				- Use `@export var` instead of `export var`
				- Use `@onready var` instead of `onready var`
				- Use Node3D instead of Spatial, and position instead of translation
				- Use instantiate instead of instance
			"""
		},
		{
			"role": "user", 
			"content": prompt
		}
	])
	
	messageLog.append(
		{
			"role": "user", 
			"content": prompt
		}
	)
	
	var request = HTTP.request(
		API_URL, 
		["Authorization: Bearer " + api_key, "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(messages)
	)

func _on_submit_message_pressed():
	var msg = MessageEdit.text
	if len(msg) > 0:
		query_ai(msg)
		
		MessageEdit.text = ""
