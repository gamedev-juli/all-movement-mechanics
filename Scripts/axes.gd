extends Node3D

@onready var mesh0 : Node3D = $MeshInstance3D
@onready var mesh1 : Node3D = $MeshInstance3D/MeshInstance3D
@onready var character : CharacterBody3D = $"../CharacterBody3D"
@onready var camPivot : Node3D = $"../CharacterBody3D/CameraPivot"

var is_on := false
var target_basis := Basis.IDENTITY
enum JoystickAngle {RIGHT, UP, LEFT, DOWN, NEUTRAL}
var angle_to_str := {
	JoystickAngle.RIGHT: "RIGHT",
	JoystickAngle.UP: "UP",
	JoystickAngle.LEFT: "LEFT",
	JoystickAngle.DOWN: "DOWN",
	JoystickAngle.NEUTRAL: "NEUTRAL",
}
var joystick_angle := JoystickAngle.NEUTRAL
var time_since_joystick_moved : float = 0.0
const JOYSTICK_HOLD_DUR := 0.5 # s


func _ready() -> void:
	for child in find_children("*"):
		if child is MeshInstance3D:
			child.material_override.no_depth_test = true
			child.visible = false


func toggle_visiblity(new_visibility : bool) -> void:
	if new_visibility:
		
		# snap basis .x,.y and .z to one of [(+-1,0,0),(0,+-1,0),(0,0,+-1)]
		var new_y = character.up_direction
		var max_axis := character.basis.z.abs().max_axis_index()
		var new_z := Vector3.ZERO
		new_z[max_axis] = signf(character.basis.z[max_axis])
		var new_x := new_y.cross(new_z) # right-handed
		basis = Basis(new_x, new_y, new_z)
		position = character.position - camPivot.global_basis.z * 3
		target_basis = Basis.IDENTITY
		mesh0.basis = target_basis
	mesh0.visible = new_visibility
	mesh1.visible = new_visibility
	is_on = new_visibility
	

func _physics_process(delta: float) -> void:
	if not is_on:
		return
	
	# does the joystick aim up/down/left/right?
	var joystick_vector : Vector2 = Input.get_vector("look_right", "look_left", "look_down", "look_up")
	var new_joystick_angle := JoystickAngle.NEUTRAL
	if joystick_vector.length() > 0.9:
		var joystick_angle_f : float = rad_to_deg(atan2(joystick_vector.y, -joystick_vector.x))
		new_joystick_angle = posmod(int(floor((joystick_angle_f + 45) / 90.0)), 4) as JoystickAngle
	
	if new_joystick_angle == JoystickAngle.NEUTRAL and joystick_angle != JoystickAngle.NEUTRAL:
		time_since_joystick_moved = INF
	elif joystick_angle != JoystickAngle.NEUTRAL and new_joystick_angle == joystick_angle:
		time_since_joystick_moved += delta
	else:
		time_since_joystick_moved = 0
		
	if time_since_joystick_moved > JOYSTICK_HOLD_DUR:
		if joystick_angle == JoystickAngle.UP:
			target_basis = target_basis.rotated(Vector3.RIGHT, -PI * 0.5)
		elif joystick_angle == JoystickAngle.DOWN:
			target_basis = target_basis.rotated(Vector3.RIGHT, PI * 0.5)
		elif joystick_angle == JoystickAngle.RIGHT:
			target_basis = target_basis.rotated(Vector3.FORWARD, PI * 0.5)
		elif joystick_angle == JoystickAngle.LEFT:
			target_basis = target_basis.rotated(Vector3.FORWARD, -PI * 0.5)
		time_since_joystick_moved = 0
		
	if mesh0.basis != target_basis:
		mesh0.basis = mesh0.basis.slerp(target_basis, 10.0 * delta)
		
	joystick_angle = new_joystick_angle
	
