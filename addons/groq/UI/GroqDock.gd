@tool
extends Control
class_name GroqDock

@onready var MessageEdit = $MessagingBox/MessageEdit
@onready var HTTP = $HTTPRequest
@onready var ChatLogVbox = $ChatLogContainer/ChatLogVbox

const API_URL = "https://api.groq.com/openai/v1/chat/completions"
var model

var messageLog = []

var waitingForApiKey = false

var hasAddedToContext = false

# Called when the node enters the scene tree for the first time.
func _ready():
	HTTP.request_completed.connect(_on_request_completed)
	
	EditorInterface.get_script_editor().get_current_editor().get_child(1).id_pressed.connect(_script_context_menu_pressed)
	
func _script_context_menu_pressed(id):
	match id:
		1001:
			query_ai(
				"Explain this code: ", 
				EditorInterface.get_script_editor().get_current_editor().get_base_editor().get_selected_text() + 
				"```"
				)
		1002:
			query_ai(
				"Fix this code: ", 
				EditorInterface.get_script_editor().get_current_editor().get_base_editor().get_selected_text() + 
				"```"
				)

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
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not hasAddedToContext:
		hasAddedToContext = true
				
		EditorInterface.get_script_editor().get_current_editor().get_child(1).add_separator()
		EditorInterface.get_script_editor().get_current_editor().get_child(1).add_item("AI: Explain", 1001)
		EditorInterface.get_script_editor().get_current_editor().get_child(1).add_item("AI: Fix Code", 1002)
	elif not EditorInterface.get_script_editor().get_current_editor().get_child(1).visible:
		hasAddedToContext = false
	
func add_chat_label(text, tooltip = ""):
	var l = RichTextLabel.new()
	l.fit_content = true
	l.selection_enabled = true
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.tooltip_text = tooltip
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
		return
		
	var msg = json.choices[0].message.content
	msg = msg.replace("```", "\n")
	
	add_chat_label("AI: " + msg, "Model: " + json.model)
	
	messageLog.append(
		{
			"role": "assistant", 
			"content": json.choices[0].message.content
		}
	)

func query_ai(prompt, selection = "NONE"):
	
	var selectionMsg = ""

	if EditorInterface.get_script_editor().get_current_editor().get_base_editor().get_selected_text() == "" or null:
		pass
	else:
		selection = EditorInterface.get_script_editor().get_current_editor().get_base_editor().get_selected_text()
		
		selectionMsg = "\n Selection: ```\n" + selection + "```"
	
	var config = ConfigFile.new()
	var err = config.load("res://addons/groq/plugin.cfg")
	model = config.get_value("ai", "model")
	
	config = ConfigFile.new()
	err = config.load(get_home_directory() + "/.godot-groq.cfg")
	
	add_chat_label("You: " + prompt + (" {selection}" if selection != "NONE" else ""))
	
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
	
	var data = {
			"messages": messageLog,
			"model": model
		}
	
	data.messages.append_array([
		{
			"role": "system",
			"content": """
				You are an Godot 4 assistant, your defaulth coding language is GDScript, but godot also supports C#, only give a solution in GDscript, unless user wants to use C#.
				- You NOT allowed to use backticks (`), you can NEVER use them, you HAVE to use one newline for each backtick or ``` or `
				- Use `@export var` instead of `export var`
				- Use `@onready var` instead of `onready var`
				- Name changes in godot 4 (old : new):
					AnimatedSprite (old) : AnimatedSprite2D (new)
					ARVRCamera (old) : XRCamera3D (new)
					ARVRController (old) : XRController3D (new)
					ARVRAnchor (old) : XRAnchor3D (new)
					ARVRInterface (old) : XRInterface (new)
					ARVROrigin (old) : XROrigin3D (new)
					ARVRPositionalTracker (old) : XRPositionalTracker (new)
					ARVRServer (old) : XRServer (new)
					CubeMesh (old) : BoxMesh (new)
					EditorSpatialGizmo (old) : EditorNode3DGizmo (new)
					EditorSpatialGizmoPlugin (old) : EditorNode3DGizmoPlugin (new)
					GIProbe (old) : VoxelGI (new)
					GIProbeData (old) : VoxelGIData (new)
					GradientTexture (old) : GradientTexture1D (new)
					KinematicBody (old) : CharacterBody3D (new)
					KinematicBody2D (old) : CharacterBody2D (new)
					Light2D (old) : PointLight2D (new)
					LineShape2D (old) : WorldBoundaryShape2D (new)
					Listener (old) : AudioListener3D (new)
					NavigationMeshInstance (old) : NavigationRegion3D (new)
					NavigationPolygonInstance (old) : NavigationRegion2D (new)
					Navigation2DServer (old) : NavigationServer2D (new)
					PanoramaSky (old) : Sky (new)
					Particles (old) : GPUParticles3D (new)
					Particles2D (old) : GPUParticles2D (new)
					ParticlesMaterial (old) : ParticleProcessMaterial (new)
					Physics2DDirectBodyState (old) : PhysicsDirectBodyState2D (new)
					Physics2DDirectSpaceState (old) : PhysicsDirectSpaceState2D (new)
					Physics2DServer (old) : PhysicsServer2D (new)
					Physics2DShapeQueryParameters (old) : PhysicsShapeQueryParameters2D (new)
					Physics2DTestMotionResult (old) : PhysicsTestMotionResult2D (new)
					PlaneShape (old) : WorldBoundaryShape3D (new)
					Position2D (old) : Marker2D (new)
					Position3D (old) : Marker3D (new)
					ProceduralSky (old) : Sky (new)
					RayShape (old) : SeparationRayShape3D (new)
					RayShape2D (old) : SeparationRayShape2D (new)
					ShortCut (old) : Shortcut (new)
					Spatial (old) : Node3D (new)
					SpatialGizmo (old) : Node3DGizmo (new)
					SpatialMaterial (old) : StandardMaterial3D (new)
					Sprite (old) : Sprite2D (new)
					StreamTexture (old) : CompressedTexture2D (new)
					TextureProgress (old) : TextureProgressBar (new)
					VideoPlayer (old) : VideoStreamPlayer (new)
					ViewportContainer (old) : SubViewportContainer (new)
					Viewport (old) : SubViewport (new)
					VisibilityEnabler (old) : VisibleOnScreenEnabler3D (new)
					VisibilityNotifier (old) : VisibleOnScreenNotifier3D (new)
					VisibilityNotifier2D (old) : VisibleOnScreenNotifier2D (new)
					VisibilityNotifier3D (old) : VisibleOnScreenNotifier3D (new)
					VisualServer (old) : RenderingServer (new)
					VisualShaderNodeScalarConstant (old) : VisualShaderNodeFloatConstant (new)
					VisualShaderNodeScalarFunc (old) : VisualShaderNodeFloatFunc (new)
					VisualShaderNodeScalarOp (old) : VisualShaderNodeFloatOp (new)
					VisualShaderNodeScalarClamp (old) : VisualShaderNodeClamp (new)
					VisualShaderNodeVectorClamp (old) : VisualShaderNodeClamp (new)
					VisualShaderNodeScalarInterp (old) : VisualShaderNodeMix (new)
					VisualShaderNodeVectorInterp (old) : VisualShaderNodeMix (new)
					VisualShaderNodeVectorScalarMix (old) : VisualShaderNodeMix (new)
					VisualShaderNodeScalarSmoothStep (old) : VisualShaderNodeSmoothStep (new)
					VisualShaderNodeVectorSmoothStep (old) : VisualShaderNodeSmoothStep (new)
					VisualShaderNodeVectorScalarSmoothStep (old) : VisualShaderNodeSmoothStep (new)
					VisualShaderNodeVectorScalarStep (old) : VisualShaderNodeStep (new)
					VisualShaderNodeScalarSwitch (old) : VisualShaderNodeSwitch (new)
					VisualShaderNodeScalarTransformMult (old) : VisualShaderNodeTransformOp (new)
					VisualShaderNodeScalarDerivativeFunc (old) : VisualShaderNodeDerivativeFunc (new)
					VisualShaderNodeVectorDerivativeFunc (old) : VisualShaderNodeDerivativeFunc (new)
					VisualShaderNodeBooleanUniform (old) : VisualShaderNodeBooleanParameter (new)
					VisualShaderNodeColorUniform (old) : VisualShaderNodeColorParameter (new)
					VisualShaderNodeScalarUniform (old) : VisualShaderNodeFloatParameter (new)
					VisualShaderNodeCubeMapUniform (old) : VisualShaderNodeCubeMapParameter (new)
					VisualShaderNodeTextureUniform (old) : VisualShaderNodeTexture2DParameter (new)
					VisualShaderNodeTextureUniformTriplanar (old) : VisualShaderNodeTextureParameterTriplanar (new)
					VisualShaderNodeTransformUniform (old) : VisualShaderNodeTransformParameter (new)
					VisualShaderNodeVec3Uniform (old) : VisualShaderNodeVec3Parameter (new)
					VisualShaderNodeUniform (old) : VisualShaderNodeParameter (new)
					VisualShaderNodeUniformRef (old) : VisualShaderNodeParameterRef (new)	
			"""
		},
		{
			"role": "user", 
			"content": prompt + selectionMsg
		}
	])
	
	messageLog.append(
		{
			"role": "user", 
			"content": prompt + selectionMsg
		}
	)
	
	var request = HTTP.request(
		API_URL, 
		["Authorization: Bearer " + api_key, "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

func _on_submit_message_pressed():
	var msg = MessageEdit.text
	if len(msg) > 0:
		query_ai(msg)
		
		MessageEdit.text = ""
