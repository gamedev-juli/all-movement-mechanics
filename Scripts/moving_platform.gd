@tool
extends AnimatableBody3D

var VELOCITY : float = 2.0 # m/s
var distance : float = 5.0 # m


func _physics_process(delta):
	position = Vector3(0, 0, position.z + VELOCITY * delta)

	# reverse direction at the extremities
	if abs(position.z) > distance:
		VELOCITY = -VELOCITY
		position.z = max(min(position.z, distance), -distance)
		
	#if not forwards:
		#global_position = global_position.move_toward(init_pos, VELOCITY * delta)
		#if global_position.distance_to(init_pos) < VELOCITY * delta * 0.5:
			#forwards = true
	#else:
		#global_position = position.move_toward(init_pos + movement, VELOCITY * delta)
		#if global_position.distance_to(init_pos + movement) < VELOCITY * delta * 0.5:
			#forwards = false
