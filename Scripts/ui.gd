extends CanvasLayer

@onready var character: CharacterBody3D = $"../CharacterBody3D"
@onready var fps_label: Label = $TopLeftVBox/FPSLabel
@onready var speed_label: Label = $TopLeftVBox/SpeedLabel
@onready var scene_menu := $CenterContainer

var is_menu_shown := false

@onready var menu_buttons := [
	$CenterContainer/HBoxContainer/Button_reset,
	$CenterContainer/HBoxContainer/Button_lvl1,
	$CenterContainer/HBoxContainer/Button_lvl2,
	$CenterContainer/HBoxContainer/Button_lvl3,
	$CenterContainer/HBoxContainer/Button_lvl4,
	$CenterContainer/HBoxContainer/Button_lvl5,
]
const LEVELS := [
	"res://Scenes/lvl1.tscn",
	"res://Scenes/lvl2.tscn",
	"res://Scenes/lvl3.tscn",
	"res://Scenes/lvl4.tscn",
	"res://Scenes/lvl5.tscn",
]

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	scene_menu.hide()
	for i in menu_buttons.size():
		menu_buttons[i].pressed.connect(_on_scene_selected.bind(i))


func _on_scene_selected(i: int):
	get_tree().paused = false # unpause game
	if i == 0:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(LEVELS[i - 1])


func _process(_delta):
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	speed_label.text = "Speed: %2.0f m/s" % character.get_real_velocity().length()


func _unhandled_input(event):
	if event.is_action_pressed("menu"):
		print("menu ", is_menu_shown)
		if not is_menu_shown:
			get_tree().paused = true # pause game (except this node)
			scene_menu.show()
			menu_buttons[0].grab_focus()
			is_menu_shown = true
		else:
			scene_menu.hide()
			is_menu_shown = false
			get_tree().paused = false # unpause game
