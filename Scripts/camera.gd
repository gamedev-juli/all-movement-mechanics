extends Camera3D

@onready var character : CharacterBody3D = $"../CharacterBody3D"
@onready var character_mesh : MeshInstance3D = $"../CharacterBody3D/MeshInstance3D"
@onready var pivot_free : Node3D = $"../CharacterBody3D/CameraPivot"
@onready var pivot_climb : Node3D = $"../CharacterBody3D/CameraPivot/SpringArm3D/CameraPivotClimb"
@export var follow_character : bool = true

const LERP_SPEED := 2.0
var cam_perc := 0.0

# cam shake heavily inspired by https://www.youtube.com/watch?v=pG4KGyxQp40
const SHAKE_STRENGTH : float = 0.4
const SHAKE_FREQ : float = 5.0
var shake_duration := 0.5 # s
var shake_time_elapsed : float = INF #s
var noise := FastNoiseLite.new()


func _physics_process(delta: float) -> void:
	if not follow_character:
		return
	
	if character.state == character.State.CLIMB:
		if cam_perc < 1:
			cam_perc += LERP_SPEED * delta
			cam_perc = min(cam_perc, 1.0)
			character_mesh.transparency = max(1 - cam_perc, 0.0)
			interpolate_transform()
		else:
			transform = pivot_climb.global_transform
	else:
		if cam_perc > 0:
			cam_perc -= LERP_SPEED * delta
			cam_perc = max(cam_perc, 0.0)
			character_mesh.transparency = min(1 - cam_perc, 1.0)
			interpolate_transform()
		else:
			transform = pivot_free.global_transform
			
	# cam shake
	if shake_time_elapsed < shake_duration:
		shake_time_elapsed += delta
		var offset := Vector2(noise.get_noise_1d(shake_time_elapsed), noise.get_noise_1d(shake_time_elapsed + 5))
		offset *= SHAKE_STRENGTH * (1 - shake_time_elapsed / shake_duration)
		h_offset = offset.x
		v_offset = offset.y
	else:
		h_offset = 0
		v_offset = 0


func interpolate_transform() -> void:
	var t : float = ease(cam_perc, -4.0)
	position = lerp(pivot_free.global_position, pivot_climb.global_position, t)
	basis = Basis(pivot_free.global_basis.get_rotation_quaternion().slerp(pivot_climb.global_basis.get_rotation_quaternion(), t))


func start_cam_shake() -> void:
	randomize()
	noise.seed = randi()
	noise.frequency = SHAKE_FREQ
	shake_time_elapsed = 0
