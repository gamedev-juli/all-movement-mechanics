extends CharacterBody3D

# NOTE: This code assumes the character is a cylinder: radius 0.5m, height 2m.
#       E.g. bottom of cylinder ("feet") is at -1m vertically (except when crouching, where scale is halved)
# NOTE: Player can change the concept of "up" (see up_direction)
#       So code uses basis or AXES instead of (Vector3.RIGHT, Vector3.UP, Vector3.BACKWARD).
#       Code makes sure that basis is always orthonormal and right-handed.
# NOTE: CharacterBody3D is always a child of the root node, 
#       so position, rotation, transform etc. are all equivalent to their global counterparts.


# children
@onready var character_collision_shape : CollisionShape3D = $CollisionShape3D
@onready var character_mesh : MeshInstance3D = $MeshInstance3D
@onready var camPivot : Node3D = $CameraPivot

# other objects in the scene
@onready var camera : Camera3D = $"../Camera3D"
@onready var crosshairRay : RayCast3D = $"../Camera3D/RayCast3D"
@onready var crosshair_ui : Control = $"../CanvasLayer/Crosshair"
@onready var grapple_point_visualizer : MeshInstance3D = $"../GrapplePointMesh"
@onready var grapple_ui_manager : Control = $"../CanvasLayer/GrappleUIManager"
@onready var portal0 : Node3D = $"../Portals/Portal0"
@onready var portal1 : Node3D = $"../Portals/Portal1"
@onready var portal_manager : Node3D = $"../Portals"
@onready var slingshot : Node3D = $"../Slingshot"
@onready var rope : Node3D = $"../Rope"
@onready var axes_ui : Node3D = $"../Axes"

# state maching
enum State {FREE, CROUCH, CLIMB, GRAPPLE_TF, GRAPPLE_SEKIRO, GRAPPLE_SPIDERMAN, GRAPPLE, WALLRUN, FLY_CREATIVE, FLY_ELYTRA, GROUND_POUND, RAIL_GRINDING, RAIL_SWITCH, SLINGSHOT, SWITCH_GRAVITY}
var state : State = State.FREE
var is_first_frame := false
var should_move_and_slide := false
const state_to_string := {
	State.FREE: "FREE",
	State.CROUCH: "CROUCH",
	State.CLIMB: "CLIMB",
	State.GRAPPLE_TF: "GRAPPLE_TF",
	State.GRAPPLE_SEKIRO: "GRAPPLE_SEKIRO",
	State.GRAPPLE_SPIDERMAN: "GRAPPLE_SPIDERMAN",
	State.GRAPPLE: "GRAPPLE",
	State.WALLRUN: "WALLRUN",
	State.FLY_CREATIVE: "FLY_CREATIVE",
	State.FLY_ELYTRA: "FLY_ELYTRA",
	State.GROUND_POUND: "GROUND_POUND",
	State.RAIL_GRINDING: "RAIL_GRINDING",
	State.RAIL_SWITCH: "RAIL_SWITCH",
	State.SLINGSHOT: "SLINGSHOT",
	State.SWITCH_GRAVITY: "SWITCH_GRAVITY",
}
var physics_process_states := {
	State.FREE: physics_process_free,
	State.CROUCH: physics_process_crouch,
	State.CLIMB: physics_process_climb,
	State.GRAPPLE_TF: physics_process_grapple_titanfall,
	State.GRAPPLE_SPIDERMAN: physics_process_grapple_spiderman,
	State.GRAPPLE_SEKIRO: physics_process_grapple_sekiro,
	State.GRAPPLE: physics_process_grapple,
	State.WALLRUN: physics_process_wallrun,
	State.FLY_CREATIVE: physics_process_fly_creative,
	State.GROUND_POUND: physics_process_ground_pound,
	State.RAIL_GRINDING: physics_process_rail_grinding,
	State.RAIL_SWITCH: physics_process_rail_switch,
	State.SLINGSHOT: physics_process_slingshot,
	State.SWITCH_GRAVITY: physics_process_switch_gravity,
}

# basic movement
var camPitch := 0.0
var camYaw := 0.0
const GRAVITY = 9.8 # m/s^2
var AXES := Basis.IDENTITY
const ROT_SPEED = 2.0  # radians/s
const SPEED = 6.0  # m/s
const ACCELERATION = 30.0  # m/s^2
const AIR_ADDITIONAL_SPEED = 2.0  # m/s
const AIR_ADDITIONAL_ACCELERATION = 10.0  # m/s^2
const TERMINAL_SPEED = 50.0  # m/s
var on_floor := false
var prev_on_floor := false
var tween_lock := false
var init_cam_pos := Vector3.ZERO
var init_transform := Transform3D.IDENTITY
var head_bobbing_phase := 0.0
var head_bobbing_elapsed_time := 0.0
const HEAD_BOBBING_MAX_TIME := 3.0
var platform_velocity := Vector3.ZERO

# jump
const JUMP_SPEED = 5.0  # m/s
var is_pressing_jump := false # for immediately jumping again when landing and holding down jump
var nr_jumps_done : int = 0

# crouch
const CROUCH_SPEED = 3.0  # m/s
var try_uncrouch := false
var actually_uncrouch := false
var character_scale : float = 1.0

# dash
const GROUND_DASH_SPEED = 10.0  # m/s
const AIR_DASH_SPEED = 6.0  # m/s
const DASH_CD = 0.5  # s
var can_air_dash_again := false
var time_since_ground_dash : float = INF

# climbing
const CLIMB_SPEED = 4.0 # m/s
var last_wall_position := Vector3.ZERO
enum JoystickAngle {RIGHT, UP, LEFT, DOWN, NEUTRAL}
enum YawAngle {RIGHT, FORWARD, LEFT, BACKWARD}
enum WallJumpDir {RIGHT, UP, LEFT, DOWN, BACKWARDS, NONE}
const walljumpdir_to_string := {
	WallJumpDir.RIGHT : "RIGHT",
	WallJumpDir.UP : "UP",
	WallJumpDir.LEFT : "LEFT",
	WallJumpDir.DOWN : "DOWN",
	WallJumpDir.BACKWARDS : "BACKWARDS",
	WallJumpDir.NONE : "NONE"
}
const angles_to_wall_jump_dir := {
	YawAngle.FORWARD: {
		JoystickAngle.RIGHT: WallJumpDir.RIGHT,
		JoystickAngle.UP: WallJumpDir.UP,
		JoystickAngle.LEFT: WallJumpDir.LEFT,
		JoystickAngle.DOWN: WallJumpDir.DOWN,
		JoystickAngle.NEUTRAL: WallJumpDir.BACKWARDS,
	},
	YawAngle.BACKWARD: {
		JoystickAngle.RIGHT: WallJumpDir.LEFT,
		JoystickAngle.UP: WallJumpDir.UP,
		JoystickAngle.LEFT: WallJumpDir.RIGHT,
		JoystickAngle.DOWN: WallJumpDir.DOWN,
		JoystickAngle.NEUTRAL: WallJumpDir.BACKWARDS,
	},
	YawAngle.LEFT: {
		JoystickAngle.RIGHT: WallJumpDir.NONE,
		JoystickAngle.UP: WallJumpDir.LEFT,
		JoystickAngle.LEFT: WallJumpDir.BACKWARDS,
		JoystickAngle.DOWN: WallJumpDir.RIGHT,
		JoystickAngle.NEUTRAL: WallJumpDir.UP,
	},
	YawAngle.RIGHT: {
		JoystickAngle.RIGHT: WallJumpDir.BACKWARDS,
		JoystickAngle.UP: WallJumpDir.RIGHT,
		JoystickAngle.LEFT: WallJumpDir.NONE,
		JoystickAngle.DOWN: WallJumpDir.LEFT,
		JoystickAngle.NEUTRAL: WallJumpDir.UP,
	}
}
var wall_jump_dir : WallJumpDir
var wall_jump_vert_cd := 0.5
var wall_jump_previous_angle := 0.0
var time_since_last_wall_jump_vert := wall_jump_vert_cd + 1.0

# glide
const GLIDE_SPEED := 3.0

# grapple
var grapple_point := Vector3.ZERO
var grapple_init_dir := Vector3.ZERO
const SWING_MIN_SPEED := 10.0
const SWING_WIDTH := 5.0
const GRAPPLE_SEKIRO_DURATION := 1.0

# wallrun
const WALLRUN_MAX_DUR := 3.0 # s
const WALLRUN_SPEED := 10.0 # m/s
var wallrum_time_elapsed := 0.0
var prev_wall_normal := Vector3.ZERO

# fly minecraft creative
const FLY_CREATIVE_SPEED := 10.0 # m/s
const FLY_CREATIVE_ACCELERATION := 30.0 # m/s^2

# swim
var next_is_in_water := false # changed using signals from Area3D in BodiesOfWater
var is_swimming := false
const SWIM_SPEED := 5.0 # m/s
const SWIM_CROUCH_SPEED := 2.5 # m/s
const SWIM_ACCELERATION := 5.0 # m/s^2

# ground pound
const GROUND_POUND_SPEED := 25.0 # m/s

# portals
var portal_swap := false
var just_portal_swapped := false
var from_portal : Transform3D
var to_portal : Transform3D

# rail grinding
var rail_polygon : CSGPolygon3D = null
var rail_path : Path3D = null
var rail_curve : Curve3D = null
var rail_length : float = 0.0
var invert_path := false
var offset_along_rail : float = 0.0
const RAIL_SPEED := 10.0 # m/s
var time_since_last_rail : float = INF
var init_char_transform := Transform3D.IDENTITY
var init_curve_transform := Transform3D.IDENTITY

# slingshot
var is_slingshot_visible := false
const SLINGSHOT_WINDUP : float = 2.0 # s
var passed_windup_time : float = 0.0 # s
const SLINGSHOT_SPEED := 15.0 # m/s
const SLINGSHOT_WALK_SPEED := 2.0 # m/s

# changing gravity direction
var velocity_before_pause := Vector3.ZERO


func _ready() -> void:
	floor_max_angle = deg_to_rad(80) # default 45 degrees
	init_cam_pos = camPivot.position
	init_transform = transform
	crosshairRay.add_exception(self)
	character_mesh.transparency = 1

###################### physics_process() #######################

func _physics_process(delta: float) -> void:
	
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
		return
	
	if tween_lock:
		return
	
	# portal swap
	if portal_swap:
		actually_portal_swap()
	
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction : Vector3 = basis * Vector3(input_movement_vector.x, 0, input_movement_vector.y)
	
	is_swimming = next_is_in_water
	if (just_portal_swapped or is_swimming) and state not in [State.FREE, State.CROUCH, State.SLINGSHOT, State.SWITCH_GRAVITY]:
		# properly end the current state
		if state == State.CLIMB:
			end_state_climb()
		elif state in [State.GRAPPLE_TF, State.GRAPPLE_SEKIRO, State.GRAPPLE]:
			end_state_grapple()
		elif state == State.WALLRUN:
			end_state_wallrun()
		elif state in [State.RAIL_GRINDING, State.RAIL_SWITCH]:
			end_state_rail()
		# set the new state
		state = State.FREE
		just_portal_swapped = false
	
	if state == State.FREE:
		check_for_new_state(delta, input_movement_vector, move_direction)
	
	if state not in [State.RAIL_GRINDING, State.RAIL_SWITCH, State.SWITCH_GRAVITY]:
		on_floor = is_on_floor()
		# preserve momentum
		if not should_move_and_slide:
			velocity = get_real_velocity() - platform_velocity
		else:
			should_move_and_slide = false # reset
		# preserve momentum on landing
		if on_floor and not prev_on_floor:
			velocity = velocity.slide(get_floor_normal())
		prev_on_floor = on_floor
		
	# sanity check camPivot rotation
	if not state in [State.CLIMB, State.RAIL_GRINDING, State.RAIL_SWITCH] and camPivot.rotation.y != 0:
		push_warning("camera and character not aligned! ", camPivot.rotation.y, " should be 0")
	
	# rotate so character's UP is the same as up_direction
	if state not in [State.CLIMB, State.RAIL_GRINDING, State.RAIL_SWITCH, State.SWITCH_GRAVITY] and basis.y != AXES.y:
		var target_forward := -basis.z.slide(AXES.y)
		var target_basis : Basis
		if target_forward.length() < 0.01:
			target_basis = Basis.looking_at(-AXES.z, AXES.y)
		else:
			target_basis = Basis.looking_at(target_forward.normalized(), AXES.y)
		var current_rot := basis.get_rotation_quaternion()
		var target_rot := target_basis.get_rotation_quaternion()
		var angle := current_rot.angle_to(target_rot)
		if angle > 0.001:
			var new_rotation := current_rot.slerp(target_rot, min(5.0 * delta / angle, 1.0))
			basis = Basis(new_rotation)
		else:
			basis = target_basis
	
	# rotate camera
	if state not in [State.GRAPPLE_SPIDERMAN, State.RAIL_GRINDING, State.RAIL_SWITCH, State.SWITCH_GRAVITY]:
		var input_rotation_vector : Vector2 = Input.get_vector("look_right", "look_left", "look_down", "look_up")
		# yaw (left <-> right)
		if state == State.CLIMB:
			camYaw += ROT_SPEED * delta * input_rotation_vector.x
			camPivot.rotation.y = camYaw
		elif state != State.SLINGSHOT:
			rotate(basis.y, ROT_SPEED * delta * input_rotation_vector.x)
		# pitch (up / down)
		camPitch += ROT_SPEED * 0.8 * delta * input_rotation_vector.y
		camPitch = clamp(camPitch, -1.57, 1.57)
		camPivot.rotation.x = camPitch
	
	var original_state := state
	
	if state == State.FLY_ELYTRA:
		physics_process_fly_elytra(delta)
		if state == State.FREE:
			check_for_new_state(delta, input_movement_vector, move_direction)
	
	# call the physics_process of the current state
	var physics_process_state: Callable = physics_process_states.get(state, Callable())
	if physics_process_state.is_valid():
		physics_process_state.call(delta)
	
	# terminal speed
	var final_speed := velocity.length()
	if final_speed > TERMINAL_SPEED:
		velocity *= TERMINAL_SPEED / final_speed
	
	if should_move_and_slide or not original_state in [State.SWITCH_GRAVITY, State.RAIL_GRINDING, State.RAIL_SWITCH]:
		move_and_slide()
		platform_velocity = get_platform_velocity()


func check_for_new_state(delta: float, input_movement_vector : Vector2, move_direction : Vector3) -> void:
	# crouch (toggle)
	if Input.is_action_just_pressed("crouch"):
		try_uncrouch = false
		actually_uncrouch = false
		is_first_frame = true
		state = State.CROUCH
		return
	
	if is_swimming:
		return
	
	# climb
	if not on_floor and check_pressing_into_wall(input_movement_vector):
		camYaw = 0
		state = State.CLIMB
		return
	
	# wall run
	if not on_floor and is_on_wall():
		# joystick should aim towards the wall, the horizontal velocity along the wall should be bigger than 1m/s, and angle between wall normal and forward should be in [45,135]
		var wall_normal : Vector3 = get_wall_normal()
		var forward_versus_wall_angle : float = basis.z.dot(wall_normal)
		var horizontal_velocity_along_wall : Vector3 = velocity.slide(wall_normal).slide(basis.y)
		if move_direction.dot(wall_normal) < 0 and horizontal_velocity_along_wall.length() > 1  and forward_versus_wall_angle < cos(deg_to_rad(45)) and forward_versus_wall_angle > cos(deg_to_rad(135)):
			wallrum_time_elapsed = 0
			prev_wall_normal = wall_normal
			state = State.WALLRUN
			return
	
	# grapple from Titan Fall 2
	if Input.is_action_just_pressed("grapple_tf") and crosshairRay.is_colliding():
		grapple_point = crosshairRay.get_collision_point()
		grapple_point_visualizer.visible = true
		grapple_point_visualizer.global_position = grapple_point
		grapple_init_dir = (grapple_point - position).normalized()
		rope.toggle_visibility(true, grapple_point)
		state = State.GRAPPLE_TF
		return
	
	# grapple from Sekiro
	if Input.is_action_just_pressed("grapple_sekiro") and grapple_ui_manager.aimed_anchor != null:
		grapple_point = grapple_ui_manager.aimed_anchor.global_position
		rope.toggle_visibility(true, grapple_point)
		is_first_frame = true
		state = State.GRAPPLE_SEKIRO
		return
	
	# grapple from Spiderman 2
	if not on_floor and Input.is_action_just_pressed("grapple_spiderman") and velocity.dot(basis.y) < -1:
		# swing in arc by determining grapple point
		is_first_frame = true
		state = State.GRAPPLE_SPIDERMAN
		return
	
	# grapple
	if Input.is_action_just_pressed("grapple") and crosshairRay.is_colliding():
		grapple_point = crosshairRay.get_collision_point()
		grapple_point_visualizer.visible = true
		grapple_point_visualizer.global_position = grapple_point
		rope.toggle_visibility(true, grapple_point)
		state = State.GRAPPLE
		return
	
	# fly minecraft creative
	if Input.is_action_just_pressed("fly_creative"):
		is_first_frame = true
		state = State.FLY_CREATIVE
		return
	
	# fly minecraft elytra
	if not on_floor and Input.is_action_just_pressed("fly_elytra"):
		is_first_frame = true
		state = State.FLY_ELYTRA
		return
	
	# ground pound
	if not on_floor and Input.is_action_just_pressed("ground_pound"):
		state = State.GROUND_POUND
		return
	
	# rail grinding
	if time_since_last_rail > 0.1:
		for i in get_slide_collision_count():
			var collision : KinematicCollision3D = get_slide_collision(i)
			var collider := collision.get_collider()
			if collider.is_in_group("rails"):
				# check if touching rail with bottom 50cm of character
				var touch_position := collision.get_position()
				if (touch_position - position).dot(basis.y) < -0.5:
					rail_polygon = collider as CSGPolygon3D
					rail_path = collider.get_node(collider.path_node) as Path3D
					rail_curve = rail_path.curve
					is_first_frame = true
					state = State.RAIL_GRINDING
					return
	else:
		time_since_last_rail += delta
	
	# slingshot
	if on_floor and Input.is_action_just_pressed("slingshot"):
		state = State.SLINGSHOT
		return
	
	# change gravity direction
	if Input.is_action_pressed("switch_gravity"):
		velocity_before_pause = velocity
		velocity = Vector3.ZERO
		crosshair_ui.toggle_visiblity(false)
		axes_ui.toggle_visiblity(true)
		state = State.SWITCH_GRAVITY
		return


func physics_process_free(delta: float) -> void:
	
	basic_movement(delta)
	
	# hop on small ledges (]5, 50[ cm high)
	handle_ledge()
	
	# bob head
	var floor_angle : float = get_floor_angle(up_direction)
	if on_floor and floor_angle <= deg_to_rad(30) and time_since_ground_dash > 0.5:
		bob_head(delta)


func physics_process_crouch(delta: float) -> void:
	# untoggle crouch
	if not is_first_frame and Input.is_action_just_pressed("crouch"):
		try_uncrouch = not try_uncrouch
	if is_first_frame:
		is_first_frame = false
	if try_uncrouch and can_uncrouch():
		actually_uncrouch = true
	if actually_uncrouch:
		try_uncrouch = false
		var old_scale : float = character_scale
		character_scale = move_toward(character_scale, 1.0, delta * 3)
		update_scale()
		# stay just above the ground
		var height_diff : float = abs(character_scale - old_scale)
		position += basis.y * height_diff
		if character_scale >= 1:
			character_scale = 1
			update_scale()
			state = State.FREE
	# shrink when starting crouch
	elif character_scale > 0.5:
		character_scale = move_toward(character_scale, 0.5, delta * 3)
		update_scale()
	
	basic_movement(delta)


func physics_process_grapple_titanfall(delta: float) -> void:
	var to_grapple_point : Vector3 = grapple_point - (position - basis.y) # from feet
	# disconnect if passing past the grapple point (or distance small)
	if grapple_init_dir.dot(to_grapple_point) < 0.5 or Input.is_action_just_released("grapple_tf"):
		end_state_grapple()
		state = State.FREE
		return
	
	#basic_movement(delta)
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction : Vector3 = basis * Vector3(input_movement_vector.x, 0, input_movement_vector.y)
	
	# Quake-like air control
	if move_direction.length_squared() > 0.1:
		var horizontal_velocity : Vector3 = velocity.slide(basis.y)
		var speed_in_move_dir = horizontal_velocity.dot(move_direction.normalized())
		var speed_to_add = AIR_ADDITIONAL_SPEED - speed_in_move_dir
		if speed_to_add > 0.0:
			velocity += move_direction * min(AIR_ADDITIONAL_ACCELERATION * delta, speed_to_add)
	
	# jump
	if on_floor and nr_jumps_done > 0:
		nr_jumps_done = 0
	if Input.is_action_just_pressed("jump") or (is_pressing_jump and on_floor):
		is_pressing_jump = true
		if nr_jumps_done < 2:
			nr_jumps_done += 1
			# initial upwards boost
			velocity = velocity.slide(basis.y) + basis.y * JUMP_SPEED
	elif Input.is_action_pressed("jump"):
		# gain extra height if keep pressing jump
		velocity += basis.y * JUMP_SPEED * delta
	else:
		is_pressing_jump = false
	
	# dash
	if time_since_ground_dash < DASH_CD:
		time_since_ground_dash += delta
	if on_floor:
		can_air_dash_again = true
	if Input.is_action_just_pressed("dash"):
		var boost_dir = -basis.z if move_direction.length() < 0.01 else move_direction.normalized()
		if on_floor:
			if time_since_ground_dash > DASH_CD:
				# boost along the slope of the floor
				boost_dir = boost_dir.slide(get_floor_normal()).normalized()
				velocity += boost_dir * GROUND_DASH_SPEED
				time_since_ground_dash = 0.0
		# less powerful dash while in the air
		elif can_air_dash_again:
			var horizontal_velocity : Vector3 = velocity.slide(basis.y)
			var velocity_direction : Vector3 = horizontal_velocity.normalized() if horizontal_velocity.length() > 0.01 else Vector3.ZERO
			if velocity_direction.dot(boost_dir) > cos(deg_to_rad(45)):
				# half-power additive boost
				velocity = horizontal_velocity + boost_dir * AIR_DASH_SPEED * 0.5
			else:
				# full-power overwriting boost (lurch) to course-correct
				velocity = boost_dir * AIR_DASH_SPEED
			velocity += 3 * basis.y # slight upwards boost
			can_air_dash_again = false
	
	var grapple_direction : Vector3 = to_grapple_point.normalized()
	var velocity_grapple : float = velocity.dot(grapple_direction)
	var velocity_other : Vector3 = velocity.slide(grapple_direction)
	velocity = velocity_other + min(velocity_grapple + 20.0 * delta, 20.0) * grapple_direction


func physics_process_grapple_sekiro(delta: float) -> void:
	
	# check for another sekiro grapple
	if Input.is_action_just_pressed("grapple_sekiro"):
		if grapple_ui_manager.aimed_anchor != null:
			grapple_point = grapple_ui_manager.aimed_anchor.global_position
			rope.toggle_visibility(true, grapple_point)
			is_first_frame = true
	
	var to_grapple_point : Vector3 = grapple_point - (position - basis.y) # from feet
	if is_first_frame:
		is_first_frame = false
		# launch in arc perfectly landing on grapple_point, taking gravity into account
		velocity = to_grapple_point / GRAPPLE_SEKIRO_DURATION + basis.y * 0.5 * GRAVITY * GRAPPLE_SEKIRO_DURATION
		
	# gravity
	if not on_floor:
		velocity -= AXES.y * GRAVITY * delta
	
	# leave grapple state if we are close to the end point or bumped into an obstacle
	if to_grapple_point.slide(basis.y).length() < 0.05 or (not on_floor and get_slide_collision_count() > 0):
		velocity = velocity.dot(basis.y) * basis.y
		end_state_grapple()
		state = State.FREE


func physics_process_grapple_spiderman(delta: float) -> void:
	
	# gravity
	if not on_floor:
		velocity -= AXES.y * GRAVITY * delta
	
	# define grapple point if not already defined
	if is_first_frame:
		# find the ground SWING_WIDTH meter forward (at the lowest point of the swing)
		var space_state := get_world_3d().direct_space_state
		var raycast := PhysicsRayQueryParameters3D.create(
			position - basis.z * SWING_WIDTH,
			position - basis.z * SWING_WIDTH - basis.y * SWING_WIDTH * 3
		)
		raycast.exclude = [self]
		var hit := space_state.intersect_ray(raycast)
		if not hit:
			grapple_point = position - basis.z * SWING_WIDTH
			print("default arc")
		else:
			var dist_to_floor : float = abs((position - hit.position).dot(basis.y))
			if SWING_WIDTH > dist_to_floor:
				# choose height of grapple point so that we graze the ground
				var t : float = (SWING_WIDTH*SWING_WIDTH - dist_to_floor*dist_to_floor) / (2*dist_to_floor) + 1.1
				grapple_point = position - basis.z * SWING_WIDTH + basis.y * t
				print("grazing arc")
			else:
				grapple_point = position - basis.z * SWING_WIDTH
				print("default arc")
	
	# reduce sideways tangential velocity
	var grapple_point_dir : Vector3 = (grapple_point - position).normalized()
	var tangential_vel : Vector3 = velocity.slide(grapple_point_dir)
	var tangential_speed_side : float = tangential_vel.dot(basis.x)
	var tangential_vel_rest : Vector3 = tangential_vel - tangential_speed_side * basis.x
	tangential_speed_side = move_toward(tangential_speed_side, 0, 5 * delta)
	tangential_vel = tangential_vel_rest + tangential_speed_side * basis.x
	
	# keep distance to grapple_point fixed at grapple_length
	var tangential_speed : float = tangential_vel.length()
	if tangential_speed < SWING_MIN_SPEED and tangential_speed > 0.1:
		tangential_vel = tangential_vel / tangential_speed * SWING_MIN_SPEED
	var outward_speed : float = velocity.dot(grapple_point_dir)
	if outward_speed < 0:
		outward_speed = min(0, outward_speed + delta * 50.0)
	velocity = tangential_vel + outward_speed * grapple_point_dir
		
	# release
	if not is_first_frame and Input.is_action_just_pressed("grapple_spiderman"):
		# end boost
		velocity += (basis.y - basis.z) * 2
		state = State.FREE
	
	if is_first_frame:
		is_first_frame = false


func physics_process_grapple(delta: float) -> void:
	
	basic_movement(delta)
	
	# dont increase the distance to the grapple point
	var grapple_direction : Vector3 = (grapple_point - position).normalized()
	if velocity.dot(grapple_direction) < 0:
		velocity = velocity.slide(grapple_direction)
	
	if Input.is_action_just_released("grapple"):
		end_state_grapple()
		state = State.FREE
		return


func physics_process_climb(delta: float) -> void:
	
	# orient character to face the wall
	var space_state := get_world_3d().direct_space_state
	var raycast := PhysicsRayQueryParameters3D.create(position, position - basis.z * 0.7)
	raycast.exclude = [self]
	var hit := space_state.intersect_ray(raycast)
	var ray_vert_offset := Vector3.ZERO
	if hit.is_empty():
		# try a lower ray
		ray_vert_offset = basis.y * 0.98
		raycast.from = position - ray_vert_offset
		raycast.to = raycast.from - basis.z * 0.7
		hit = space_state.intersect_ray(raycast)
		if hit.is_empty() and velocity.dot(basis.y) > 1:
			# reached the top
			end_state_climb()
			state = State.FREE
			return
			
	if not hit.is_empty():
		var wall_normal : Vector3 = hit.normal.slide(basis.y).normalized()
		# rotate towards the wall
		var angle := basis.z.signed_angle_to(wall_normal, basis.y)
		angle = clampf(angle, -ROT_SPEED * 2 * delta, ROT_SPEED * 2 * delta)
		rotate(basis.y, angle)
		# snap to exact distance from wall
		var wall_position : Vector3 = hit.position
		last_wall_position = wall_position
		position = wall_position + basis.z * 0.51 + ray_vert_offset
	
	# move character
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# scale and flip horizontal movement depending in camPivot.rotation.y
	var input_movement_vector_scaled := Vector2(input_movement_vector.x * cos(camPivot.rotation.y), input_movement_vector.y)
	if not hit.is_empty():
		var move_direction = basis * Vector3(input_movement_vector_scaled.x, -input_movement_vector_scaled.y, 0)
		velocity = velocity.move_toward(move_direction * CLIMB_SPEED, ACCELERATION * delta)
	else:
		# rotate around last_wall_position
		velocity = Vector3.ZERO
		var angle : float = input_movement_vector_scaled.x * ROT_SPEED * delta
		var wall_to_character : Vector3 = position - last_wall_position
		wall_to_character = wall_to_character.normalized() * 0.52
		wall_to_character = wall_to_character.rotated(basis.y, angle)
		position = last_wall_position + wall_to_character
		rotate(basis.y, angle)
		
	# jump
	time_since_last_wall_jump_vert += delta
	if Input.is_action_just_pressed("jump"):
		# joystick determines where to jump to
		var joystick_angle : JoystickAngle
		if input_movement_vector.length() == 0:
			joystick_angle = JoystickAngle.NEUTRAL
		else:
			var joystick_angle_f : float = rad_to_deg(atan2(-input_movement_vector.y, input_movement_vector.x))
			joystick_angle = posmod(int(floor((joystick_angle_f + 45) / 90.0)), 4) as JoystickAngle
			
		# but also the camPivot.rotation.y
		var yaw_angle : YawAngle = posmod(int(floor((rad_to_deg(camPivot.rotation.y) + 135) / 90.0)), 4) as YawAngle
		wall_jump_dir = angles_to_wall_jump_dir[yaw_angle][joystick_angle]
		if wall_jump_dir == WallJumpDir.NONE:
			return
		
		if wall_jump_dir == WallJumpDir.UP or wall_jump_dir == WallJumpDir.DOWN:
			if time_since_last_wall_jump_vert > wall_jump_vert_cd:
				time_since_last_wall_jump_vert = 0
				velocity += basis.y * 8 * (1 if wall_jump_dir == WallJumpDir.UP else -1)
			return
		
		var angle_y : float = 0.0
		if wall_jump_dir == WallJumpDir.BACKWARDS:
			var rot_dir := 1 if angle_difference(0, camPivot.rotation.y) > 0 else -1
			angle_y = rot_dir * deg_to_rad(180)
		elif wall_jump_dir == WallJumpDir.LEFT:
			angle_y = deg_to_rad(90)
		elif wall_jump_dir == WallJumpDir.RIGHT:
			angle_y = -deg_to_rad(90)
		
		wall_jump_previous_angle = 0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_method(func(angle: float):
			var delta_angle := angle - wall_jump_previous_angle
			rotate(basis.y, delta_angle)
			wall_jump_previous_angle = angle
		, 0.0, angle_y, 0.5 if wall_jump_dir == WallJumpDir.BACKWARDS else 0.25)
		tween.tween_property(camPivot, "rotation:y", 0.0, 0.5 if wall_jump_dir == WallJumpDir.BACKWARDS else 0.25)
		tween_lock = true
		await tween.finished
		tween_lock = false
		
		velocity += basis.y * 5 - basis.z * 5
		end_state_climb()
		move_and_slide()
		platform_velocity = get_platform_velocity()
		state = State.FREE
		return
	
	# check for stop climbing
	if on_floor or Input.is_action_just_pressed("crouch"):
		end_state_climb()
		state = State.FREE


func physics_process_wallrun(delta: float) -> void:
	
	# find wall_normal through raycast
	var wall_normal := Vector3.ZERO
	var space_state := get_world_3d().direct_space_state
	var raycast := PhysicsRayQueryParameters3D.create(
		position,
		position - prev_wall_normal * 0.55
	)
	raycast.exclude = [self]
	var hit := space_state.intersect_ray(raycast)
	if not hit.is_empty():
		wall_normal = hit.normal
	
	# release
	wallrum_time_elapsed += delta
	if on_floor or wall_normal == Vector3.ZERO or wallrum_time_elapsed > WALLRUN_MAX_DUR:
		end_state_wallrun()
		state = State.FREE
		return
	
	# move character
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction = basis * Vector3(input_movement_vector.x, 0, input_movement_vector.y)
	move_direction = move_direction.slide(wall_normal).normalized()
	var horizontal_velocity : Vector3 = velocity.slide(basis.y)
	var vertical_velocity : Vector3 = velocity - horizontal_velocity
	velocity = horizontal_velocity.move_toward(move_direction * SPEED, ACCELERATION * delta)
	velocity += vertical_velocity.move_toward(Vector3.ZERO, 10*delta) # maintain height
	
	# jump
	if Input.is_action_just_pressed("jump"):
		velocity += (wall_normal * 0.5 + basis.y - basis.z.slide(wall_normal) * 0.5) * JUMP_SPEED
		end_state_wallrun()
		state = State.FREE


func physics_process_fly_creative(delta: float) -> void:
	
	# move character horizontally
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction = basis * Vector3(input_movement_vector.x, 0, input_movement_vector.y)
	velocity = velocity.move_toward(Vector3(move_direction.x * FLY_CREATIVE_SPEED, velocity.y, move_direction.z * FLY_CREATIVE_SPEED), FLY_CREATIVE_ACCELERATION * delta)
	var desired_horizontal_velocity : Vector3 = move_direction * FLY_CREATIVE_SPEED
	
	# move vertically
	var desired_vertical_velocity := Vector3.ZERO
	var pressed_up : bool = Input.is_action_pressed("fly_creative_up")
	var pressed_down : bool = Input.is_action_pressed("fly_creative_down")
	if pressed_up and not pressed_down:
		desired_vertical_velocity = basis.y * FLY_CREATIVE_SPEED
	elif pressed_down and not pressed_up:
		desired_vertical_velocity = -basis.y * FLY_CREATIVE_SPEED
		
	velocity = velocity.move_toward(desired_horizontal_velocity + desired_vertical_velocity, FLY_CREATIVE_ACCELERATION * delta)
	
	# exit state
	if not is_first_frame and Input.is_action_just_pressed("fly_creative"):
		state = State.FREE
	if is_first_frame:
		is_first_frame = false


func physics_process_fly_elytra(delta: float) -> void:
	
	# if pressing any other button, return false to immediately go into the Free state
	var actions = ["jump", "crouch", "dash", "glide","grapple_spiderman", "grapple_tf", "grapple_sekiro", "grapple", "fly_creative", "ground_pound", "portal0", "portal1", "slingshot", "switch_gravity"]
	for action in actions:
		if Input.is_action_just_pressed(action):
			state = State.FREE
			return
	
	if on_floor:
		state = State.FREE
		return
	
	# fireworks
	if Input.is_action_just_pressed("fly_elytra") and not is_first_frame:
		var lookdir : Vector3 = -basis.z.rotated(basis.x, camPitch)
		velocity = lookdir * max(25.0, velocity.dot(lookdir))
	
	# heavily inspired by https://www.reddit.com/r/howdidtheycodeit/comments/vg5wn9/comment/olrq32g/?context=3
	var horizontal_speed : float = velocity.slide(basis.y).length()
	
	# gravity
	velocity -= AXES.y * GRAVITY * delta
	
	# glide: gain forward and upward speed if losing altitude
	var vertical_speed : float = velocity.dot(basis.y)
	if vertical_speed < 0:
		var glide : float = abs(vertical_speed) * cos(camPitch) * cos(camPitch)
		velocity += (-basis.z * 0.8 + basis.y) * glide * delta * 3.0
		
	# lift: if looking up, lose horizontal speed and gain upwards speed
	var pitch : float = min(camPitch + deg_to_rad(20), PI * 0.5)
	if pitch > 0:
		var lift : float = horizontal_speed * sin(pitch);
		velocity -= -basis.z * lift * delta * 0.5
		velocity += basis.y * lift * delta * 1.0
		
	# steer the horizontal velocity
	var horizontal_velocity : Vector3 = velocity.slide(basis.y)
	velocity -= (horizontal_velocity + basis.z * horizontal_speed) * delta * 2.0
	
	# drag (framerate independent)
	velocity *= pow(0.9999, delta * 60.0)
	
	if is_first_frame:
		is_first_frame = false


func physics_process_ground_pound(_delta: float) -> void:
	
	velocity = -basis.y * GROUND_POUND_SPEED
	
	if on_floor:
		camera.start_cam_shake()
		state = State.FREE


func physics_process_rail_grinding(delta: float) -> void:
	if is_first_frame:
		is_first_frame = false
		# store the camera's yaw (left <-> right)
		var original_basis_z : Vector3 = basis.z
		
		# prepare snap to rail
		rail_length = rail_curve.get_baked_length()
		var character_local_position : Vector3 = rail_path.global_transform.affine_inverse() * position
		offset_along_rail = rail_curve.get_closest_offset(character_local_position)
		
		# check if going forward or backward on the rail
		var local_transform : Transform3D = rail_curve.sample_baked_with_rotation(offset_along_rail, false, false)
		var rail_global_transform : Transform3D = rail_path.global_transform * local_transform
		invert_path = velocity.dot(-rail_global_transform.basis.z) < 0
		
		# snap to rail (with an intial twist of 0)
		if invert_path:
			local_transform.basis = local_transform.basis.rotated(local_transform.basis.y, PI)
		transform = rail_path.global_transform * local_transform
		position += local_transform.basis.y # feet on rail, not center of character
		
		# keep track of the change in twist along the rail
		init_char_transform = (rail_path.global_transform.affine_inverse() * transform)
		init_curve_transform = rail_curve.sample_baked_with_rotation(offset_along_rail, false, true)
		
		# preserve camera's pitch and yaw
		var cam_pivot_rot_x : float = camPivot.rotation.x
		camPivot.rotation.x = 0
		camPivot.rotate(basis.y, camPivot.global_basis.z.signed_angle_to(original_basis_z, basis.y))
		camPivot.rotation.x = cam_pivot_rot_x
		
	else:
		# follow rail, applying the change in twist
		offset_along_rail += RAIL_SPEED * delta * (-1 if invert_path else 1)
		if rail_curve.closed:
			if not invert_path and offset_along_rail > rail_length:
				offset_along_rail -= rail_length
			elif invert_path and offset_along_rail < 0:
				offset_along_rail += rail_length
		var new_curve_transform = rail_curve.sample_baked_with_rotation(offset_along_rail, false, true)
		var transform_delta : Transform3D = new_curve_transform * init_curve_transform.affine_inverse()
		var new_char_transform := transform_delta * init_char_transform
		transform = rail_path.global_transform * new_char_transform
		
	# interpolate camPivot x and y rotation to 0
	if not camPivot.basis.is_equal_approx(Basis.IDENTITY):
		camPivot.basis = camPivot.basis.slerp(Basis.IDENTITY, 10.0 * delta)
	
	# exit state at end of rail or jump
	var pressed_jump : bool = Input.is_action_just_pressed("jump")
	
	if pressed_jump or (not rail_curve.closed and ((not invert_path and offset_along_rail > rail_length) or (invert_path and offset_along_rail < 0))):
		var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if pressed_jump:
			if abs(input_movement_vector.x) > 0:
				# detect nearby rails to jump to
				var shape := BoxShape3D.new()
				const search_range := 8.0 # m
				shape.size = Vector3(search_range, 4, 1)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.exclude = [self]
				query.transform = Transform3D(
					basis,
					position + sign(input_movement_vector.x) * basis.x * (search_range * 0.5 + 0.5) - basis.y
				)
				var hit : Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query)
				if not hit.is_empty():
					# check if rail
					for collision in hit:
						var collider: Object = collision.collider
						if collider.is_in_group("rails") and collider != rail_polygon:
							rail_polygon = collider
							velocity = -basis.z * RAIL_SPEED
							is_first_frame = true
							state = State.RAIL_SWITCH
							return
			else:
				# jump forward and up
				velocity = -basis.z * RAIL_SPEED + basis.y * RAIL_SPEED * 0.5
		else:
			# end of rail, keep speed
			velocity = -basis.z * RAIL_SPEED
		
		end_state_rail()
		should_move_and_slide = true
		state = State.FREE
		return


func physics_process_rail_switch(_delta: float) -> void:
	if is_first_frame: # first frame
		is_first_frame = false
		
		# determine the new transform on the rail that we are switching to
		rail_path = rail_polygon.get_node(rail_polygon.path_node) as Path3D
		rail_curve = rail_path.curve
		var character_local_transform : Transform3D = rail_path.global_transform.affine_inverse() * transform
		var target_offset_along_rail = rail_curve.get_closest_offset(character_local_transform.origin)
		var target_local_transform : Transform3D = rail_curve.sample_baked_with_rotation(target_offset_along_rail, false, false)
		var should_invert_path : bool = character_local_transform.basis.z.dot(target_local_transform.basis.z) < 0
		if should_invert_path:
			target_local_transform.basis = target_local_transform.basis.rotated(target_local_transform.basis.y, PI)
		target_local_transform.origin += target_local_transform.basis.y
		var target_rail_transform : Transform3D = rail_path.global_transform * target_local_transform
		
		# tween to new transform
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(self, "position", target_rail_transform.origin, 0.3)
		tween.tween_property(self, "basis", target_rail_transform.basis, 0.3)
		tween_lock = true
		await tween.finished
		tween_lock = false
		return
	
	is_first_frame = true
	state = State.RAIL_GRINDING
	return


func physics_process_slingshot(delta: float) -> void:
	
	if not is_slingshot_visible: # first frame
		passed_windup_time = 0
		slingshot.toggle_visibility(true)
		is_slingshot_visible = true
		
	if Input.is_action_pressed("slingshot") and on_floor:
		if passed_windup_time < SLINGSHOT_WINDUP:
			# slowly walk backwards
			passed_windup_time += delta
			slingshot.update_color(passed_windup_time / SLINGSHOT_WINDUP)
			velocity = basis.z * SLINGSHOT_WALK_SPEED * lerp(1.0,0.01,passed_windup_time / SLINGSHOT_WINDUP)
			
	else:
		# release
		slingshot.toggle_visibility(false)
		is_slingshot_visible = false
		# the longer the windup, the further the slingshot
		velocity += (-basis.z + basis.y) * lerp(0.0, SLINGSHOT_SPEED, passed_windup_time / SLINGSHOT_WINDUP)
		state = State.FREE
		return


func physics_process_switch_gravity(_delta: float) -> void:
	if not Input.is_action_pressed("switch_gravity"):
		crosshair_ui.toggle_visiblity(true)
		axes_ui.toggle_visiblity(false)
		
		# snap up_direction to one of [(+-1,0,0),(0,+-1,0),(0,0,+-1)]
		up_direction = basis * axes_ui.target_basis.y
		var max_axis := up_direction.abs().max_axis_index()
		var snapped_up_direction := Vector3.ZERO
		snapped_up_direction[max_axis] = signf(up_direction[max_axis])
		up_direction = snapped_up_direction
		
		# update AXES so that AXES.y = up_direction
		var rotation_axis := AXES.y.cross(up_direction)
		var rotation_angle := AXES.y.angle_to(up_direction)
		if rotation_axis.length_squared() < 0.01: # parallel
			if AXES.y.dot(up_direction) < 0.0:
				# upside down
				rotation_axis = AXES.z.normalized()
			else:
				# no rotation needed
				rotation_axis = Vector3.ZERO
		if rotation_axis != Vector3.ZERO:
			AXES = Basis(Quaternion(rotation_axis, rotation_angle)) * AXES
		
		velocity = velocity_before_pause
		state = State.FREE


################ STATE TRANSITION HELPER METHODS ###############

func end_state_climb():
	var cam_pivot_rot_x : float = camPivot.rotation.x
	camPivot.rotation.x = 0
	rotate(basis.y, basis.z.signed_angle_to(camPivot.global_basis.z, basis.y))
	camPivot.rotation.y = 0
	camPivot.rotation.x = cam_pivot_rot_x # restore
	nr_jumps_done = 1

func end_state_grapple():
	rope.toggle_visibility(false)
	grapple_point_visualizer.visible = false

func end_state_wallrun():
	nr_jumps_done = 1

func end_state_rail():
	camPitch = 0
	camYaw = 0
	camPivot.rotation.x = 0
	camPivot.rotation.y = 0
	nr_jumps_done = 1
	time_since_last_rail = 0

######################## HELPER METHODS ########################

func basic_movement(delta: float) -> void:
	var SWIM_SPEED_ : float = SWIM_SPEED if state != State.CROUCH else SWIM_CROUCH_SPEED
	var SPEED_ : float = SPEED if state != State.CROUCH else CROUCH_SPEED
	
	var input_movement_vector : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction : Vector3 = basis * Vector3(input_movement_vector.x, 0, input_movement_vector.y)
	
	# swim
	if is_swimming:
		move_direction = move_direction.rotated(basis.x, camPitch)
		var speed := velocity.length()
		if speed > SWIM_SPEED_:
			velocity = velocity.move_toward(SWIM_SPEED_ * velocity.normalized(), SWIM_ACCELERATION * 10 * delta)
		velocity = velocity.move_toward(move_direction * SWIM_SPEED_, SWIM_ACCELERATION * delta)
		var horizontal_velocity := velocity.slide(basis.y)
		var vertical_velocity := velocity - horizontal_velocity
		var swim_up : bool = Input.is_action_pressed("swim_up")
		var swim_down : bool = Input.is_action_pressed("swim_down")
		if swim_up and not swim_down:
			vertical_velocity = vertical_velocity.move_toward(basis.y * SWIM_SPEED_, SWIM_ACCELERATION * delta * 2)
		elif swim_down and not swim_up:
			vertical_velocity = vertical_velocity.move_toward(-basis.y * SWIM_SPEED_, SWIM_ACCELERATION * delta * 2)
		velocity = horizontal_velocity + vertical_velocity
		return
	
	# walk / run / move / fall / glide
	var floor_angle : float = get_floor_angle(up_direction)
	if on_floor and floor_angle <= deg_to_rad(30):
		var desired_horizontal_velocity : Vector3 = move_direction * SPEED_
		var vertical_velocity : Vector3 = velocity.dot(basis.y) * basis.y
		velocity = velocity.move_toward(desired_horizontal_velocity + vertical_velocity, ACCELERATION * delta)
	else:
		# Quake-like air control (also on slopes)
		if move_direction.length_squared() > 0.1:
			var horizontal_velocity : Vector3 = velocity.slide(basis.y)
			var speed_in_move_dir = horizontal_velocity.dot(move_direction.normalized())
			var speed_to_add = AIR_ADDITIONAL_SPEED - speed_in_move_dir
			if speed_to_add > 0.0:
				velocity += move_direction * min(AIR_ADDITIONAL_ACCELERATION * delta, speed_to_add)
		
		# gravity
		if on_floor:
			# sliding
			var floor_normal : Vector3 = get_floor_normal()
			var slide_vector : Vector3 = (-AXES.y).slide(floor_normal)
			velocity += slide_vector * GRAVITY * delta
		else:
			if Input.is_action_pressed("glide") and velocity.dot(basis.y) < GLIDE_SPEED:
				var horizontal_velocity : Vector3 = velocity.slide(basis.y)
				velocity = velocity.move_toward(horizontal_velocity - GLIDE_SPEED * basis.y, 50 * delta)
			else:
				velocity -= AXES.y * GRAVITY * delta
	
	# jump
	if on_floor and nr_jumps_done > 0:
		nr_jumps_done = 0
	if Input.is_action_just_pressed("jump") or (is_pressing_jump and on_floor):
		is_pressing_jump = true
		if nr_jumps_done < 2:
			nr_jumps_done += 1
			# initial upwards boost
			velocity = velocity.slide(basis.y) + basis.y * JUMP_SPEED
	elif Input.is_action_pressed("jump"):
		# gain extra height if keep pressing jump
		velocity += basis.y * JUMP_SPEED * delta
	else:
		is_pressing_jump = false
	
	# dash
	if time_since_ground_dash < DASH_CD:
		time_since_ground_dash += delta
	if on_floor:
		can_air_dash_again = true
	if Input.is_action_just_pressed("dash"):
		var boost_dir = -basis.z if move_direction.length() < 0.01 else move_direction.normalized()
		if on_floor:
			if time_since_ground_dash > DASH_CD:
				# boost along the slope of the floor
				boost_dir = boost_dir.slide(get_floor_normal()).normalized()
				velocity += boost_dir * GROUND_DASH_SPEED
				time_since_ground_dash = 0.0
		# less powerful dash while in the air
		elif can_air_dash_again:
			var horizontal_velocity : Vector3 = velocity.slide(basis.y)
			var velocity_direction : Vector3 = horizontal_velocity.normalized() if horizontal_velocity.length() > 0.01 else Vector3.ZERO
			if velocity_direction.dot(boost_dir) > cos(deg_to_rad(45)):
				# half-power additive boost
				velocity = horizontal_velocity + boost_dir * AIR_DASH_SPEED * 0.5
			else:
				# full-power overwriting boost (lurch) to course-correct
				velocity = boost_dir * AIR_DASH_SPEED
			velocity += 3 * basis.y # slight upwards boost
			can_air_dash_again = false
	
	# shoot portals
	var shoot_portal0 : bool = Input.is_action_just_pressed("portal0")
	var shoot_portal1 : bool = Input.is_action_just_pressed("portal1")
	if (shoot_portal0 or shoot_portal1) and crosshairRay.is_colliding():
		var surface = crosshairRay.get_collider()
		if surface is StaticBody3D:
			portal_manager.update_portal(
				shoot_portal0, shoot_portal1, 
				crosshairRay.get_collision_point(), 
				crosshairRay.get_collision_normal(),
				surface)


func bob_head(delta: float) -> void:
	# bob camera up and down
	var horizontal_speed : float = velocity.slide(basis.y).length() 
	if horizontal_speed < 1:
		# restart head bobbing from stand still
		head_bobbing_elapsed_time = 0
	if head_bobbing_elapsed_time < HEAD_BOBBING_MAX_TIME:
		head_bobbing_elapsed_time += delta
	head_bobbing_phase += 15 * clamped_lerp(0.0, 2.0, horizontal_speed * 0.1) * delta
	var amplitude : float = clamped_lerp(0.0, 0.1, horizontal_speed * 0.1)
	# reduce head bobbing after some time
	amplitude *= clamped_lerp(1, 0.2, head_bobbing_elapsed_time / HEAD_BOBBING_MAX_TIME)
	camPivot.position = init_cam_pos + Vector3(amplitude * 0.5 * cos(0.5*head_bobbing_phase), amplitude * sin(head_bobbing_phase), 0)


func update_scale() -> void:
	# scale / reposition children
	var new_scale := Vector3(character_scale, character_scale, character_scale)
	character_collision_shape.scale = new_scale
	character_mesh.scale = new_scale
	camPivot.position.y = init_cam_pos.y * character_scale


func can_uncrouch() -> bool:
	# find the ground
	var space_state := get_world_3d().direct_space_state
	var ray_start := position
	var ray_end := position - 2 * basis.y
	var ray := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	ray.exclude = [self]
	var hit := space_state.intersect_ray(ray)
	if hit.is_empty():
		return true
	var ground_position: Vector3 = hit.position
	
	# test if a full size character fits on the ground (take slopes into account)
	var cylinder_shape := character_collision_shape.shape.duplicate() as CylinderShape3D
	var extra_height_due_to_slope : float = ((position - ground_position).dot(basis.y) - 0.5) * 2 + 1
	var cylinder_center := ground_position + basis.y * extra_height_due_to_slope
	cylinder_shape.height *= 0.95
	
	var raycast := PhysicsShapeQueryParameters3D.new()
	raycast.shape = cylinder_shape
	raycast.transform = Transform3D(basis, cylinder_center)
	raycast.exclude = [self]
	raycast.collision_mask = collision_mask
	return space_state.intersect_shape(raycast).is_empty()


func clamped_lerp(a: float, b: float, weight: float) -> float:
	return lerp(a, b, clampf(weight, 0.0, 1.0))


func handle_ledge() -> void:
	var horizontal_velocity : Vector3 = velocity.slide(basis.y)
	if horizontal_velocity.length() < 0.1:
		return
	
	var delta := 0.2 # look ahead 0.2 seconds in time for ledges
	var radius : Vector3 = 0.49 * velocity.normalized()
	var desired_displacement : Vector3 = velocity * delta
	
	var space_state := get_world_3d().direct_space_state
	var raycast := PhysicsRayQueryParameters3D.new()
	raycast.exclude = [self]
	# check if ledge is < 0.5m height by
	# casting a ray from 0.5m above feet towards where we are going
	raycast.from = position + radius - basis.y * 0.5
	raycast.to = raycast.from + desired_displacement
	var is_ledge_small : bool = space_state.intersect_ray(raycast).is_empty()
	if not is_ledge_small:
		return 
	# find the vertical part of the ledge using raycasts at [5, 15, 25, 35] cm above feet
	var distance_to_ledge = null
	for i in range(4):
		raycast.from = position + radius + basis.y * (0.05 + 0.1 * i - 1)
		raycast.to = raycast.from + desired_displacement
		var hit : Dictionary = space_state.intersect_ray(raycast)
		if not hit:
			# there is no ledge
			return
		# check if we hit the vertical part of the ledge, or just the sloped floor
		if hit.normal.dot(basis.y) < cos(deg_to_rad(80)):
			distance_to_ledge = (hit.position - raycast.from).length()
			break
	if distance_to_ledge == null:
		# there is no ledge, just a sloped floor
		return
	# find closest position on top of the ledge
	raycast.from = position + radius + desired_displacement * (distance_to_ledge + 0.01)
	raycast.to = raycast.from - basis.y
	var hit_ledge : Dictionary = space_state.intersect_ray(raycast)
	if not hit_ledge:
		return
	var ledge_position : Vector3 = hit_ledge.position
	
	# calculate the vertical velocity necessary to perfectly land on the ledge_position
	var to_ledge : Vector3 = ledge_position - position
	var horizontal_distance : float = max(0.0, to_ledge.slide(basis.y).length() - 0.5)
	var t = horizontal_distance / horizontal_velocity.length()
	var dy = to_ledge.dot(basis.y) + 1
	var new_vertical_velocity : float = dy / t + 0.5 * GRAVITY * t
	new_vertical_velocity *= 1.05 # should work without this extra boost, but for some reason it doesnt
	new_vertical_velocity = min(new_vertical_velocity, 4.0)
	if velocity.dot(basis.y) < new_vertical_velocity:
		velocity = horizontal_velocity + basis.y * new_vertical_velocity


func check_pressing_into_wall(input_movement_vector: Vector2) -> bool:
	# check if joystick is moving forward
	if input_movement_vector.y > -0.8:
		return false
	
	# check if facing a wall
	var space_state := get_world_3d().direct_space_state
	var raycast := PhysicsRayQueryParameters3D.create(
		position,
		position - basis.z * 0.53
	)
	raycast.exclude = [self]
	var hit := space_state.intersect_ray(raycast)
	if hit.is_empty():
		return false
	if hit.collider == portal0 or hit.collider == portal1:
		return false
	if hit.collider.is_in_group("rails") or hit.collider is AnimatableBody3D:
		return false
	
	last_wall_position = hit.position
	return true


func do_portal_swap(from_portal_ : Transform3D, to_portal_  : Transform3D) -> void:
	portal_swap = true
	from_portal = from_portal_
	to_portal = to_portal_


func actually_portal_swap() -> void:
	portal_swap = false
	
	# velocity to local axial system of from_portal
	var velocity_local = from_portal.basis.inverse() * velocity
	# velocity to local axial system of to_portal, by mirroring around the local x and y axes
	var flip_xy = Basis(
		Vector3(-1, 0, 0),
		Vector3(0, -1, 0),
		Vector3(0, 0, 1)
	)
	velocity_local = flip_xy * velocity_local
	# velocity to global axial system
	velocity = to_portal.basis * velocity_local
	
	# teleport character to new transform
	var transform_local : Transform3D = from_portal.affine_inverse() * transform
	transform_local.basis = portal_manager.FLIPXY * transform_local.basis
	transform_local.origin *= Vector3(-1, -1, 1)
	transform = to_portal * transform_local
	
	# end states properly
	just_portal_swapped = true
	should_move_and_slide = true
