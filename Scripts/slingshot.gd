extends Node3D

@onready var character : CharacterBody3D = $"../CharacterBody3D"
@onready var pole_left : MeshInstance3D = $PoleLeft
@onready var pole_right : MeshInstance3D = $PoleRight
@onready var attachment_left : Marker3D = $PoleLeft/Marker3D
@onready var attachment_right : Marker3D = $PoleRight/Marker3D
@onready var rope : Node3D = $"../Rope"

@export var color_start : Color = Color.RED
@export var color_end : Color = Color.GREEN

var material_poles : Material

func _ready() -> void:
	material_poles = pole_left.material_override
	pole_left.visible = false
	pole_right.visible = false


func toggle_visibility(should_be_visible : bool) -> void:
	if should_be_visible:
		material_poles.albedo_color = color_start
		transform = character.transform
		position += -character.basis.z * 3 - character.basis.y
		rope.toggle_visibility(should_be_visible, attachment_left.global_position, true, attachment_right.global_position)
	else:
		await get_tree().create_timer(0.5).timeout # wait before turning invisible
		rope.toggle_visibility(should_be_visible)
	pole_left.visible = should_be_visible
	pole_right.visible = should_be_visible


func update_color(percentage_done : float) -> void:
	percentage_done = clamp(percentage_done, 0.0, 1.0)
	# hue: red -> green
	var color := Color.from_hsv(lerpf(0.0, 0.3, percentage_done), 0.9, 1.0)
	material_poles.albedo_color = color
