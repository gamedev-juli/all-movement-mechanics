@tool
extends Control

@onready var crosshairRay : RayCast3D = $"../../Camera3D/RayCast3D"
@onready var camera : Camera3D = $"../../Camera3D"

@export var colorHit: Color = Color.WHITE
@export var colorNoHit: Color = Color.WHITE
@export var thickness := 2.0
@export var length := 5.0
@export var gap := 0.0

var is_colliding := true
var color : Color
var should_draw := true

func _ready():
	color = colorHit
	queue_redraw()

func _draw():
	if not camera.current or not should_draw:
		return
	# top, bottom, left, right
	#draw_rect(Rect2(Vector2(-thickness / 2, -gap - length), Vector2(thickness, length)), color)
	#draw_rect(Rect2(Vector2(-thickness / 2, gap), Vector2(thickness, length)), color)
	draw_rect(Rect2(Vector2(-gap - length, -thickness / 2), Vector2(length, thickness)), color)
	draw_rect(Rect2(Vector2(gap, -thickness / 2), Vector2(length, thickness)), color)

func _physics_process(_delta: float) -> void:
	var new_is_colliding : bool = crosshairRay.is_colliding()
	if new_is_colliding != is_colliding:
		is_colliding = new_is_colliding
		color = colorHit if is_colliding else colorNoHit
		queue_redraw()


func toggle_visiblity(new_visibility : bool) -> void:
	should_draw = new_visibility
	queue_redraw()
