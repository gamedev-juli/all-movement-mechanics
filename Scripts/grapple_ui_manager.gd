extends Control

@onready var camera : Camera3D = $"../../Camera3D"
@export var unselected_color := Color.WHITE
@export var selected_color := Color.GREEN

const MAX_DIST : float = 30.0
var grapple_anchors : Array[Node3D] = []
var anchor_is_visible : Dictionary = {}
var dist_perc : Dictionary = {}
var screen_pos : Dictionary = {}
var aimed_anchor : Node3D = null

func _ready():
	var grapple_anchors_tmp : Array[Node] = get_tree().get_nodes_in_group("grapple_anchors")
	for anchor_tmp in grapple_anchors_tmp:
		var anchor : Node3D = anchor_tmp as Node3D
		grapple_anchors.append(anchor)
		anchor_is_visible[anchor] = false
		screen_pos[anchor] = Vector2.ZERO
	

func _process(_delta):
	var center = get_viewport_rect().size * 0.5
	aimed_anchor = null
	var best_distance = INF
	for anchor in grapple_anchors:
		# behind camera or too far means not visible
		var dist : float = (anchor.global_position - camera.global_position).length()
		if camera.is_position_behind(anchor.global_position) or dist > 2 * MAX_DIST:
			anchor_is_visible[anchor] = false
			continue
		anchor_is_visible[anchor] = true
		
		dist_perc[anchor] = clamp(2 - 1.0 / MAX_DIST * dist, 0, 1)

		var screen : Vector2 = camera.unproject_position(anchor.global_position)
		screen_pos[anchor] = screen
		var screen_distance = screen.distance_to(center)
		if screen_distance < best_distance and dist < MAX_DIST:
			best_distance = screen_distance
			aimed_anchor = anchor
	
	queue_redraw()


func _draw():
	for anchor in grapple_anchors:
		if not anchor_is_visible[anchor]:
			continue
		draw_arc(screen_pos[anchor], 11.0, -PI * 0.5, dist_perc[anchor] * TAU - PI * 0.5, 32, unselected_color if anchor != aimed_anchor else selected_color, 1.0, true)
		draw_circle(screen_pos[anchor], 8, unselected_color if anchor != aimed_anchor else selected_color, true, -1, true)
