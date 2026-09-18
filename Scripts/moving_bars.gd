extends Node3D

@export var count : int = 60
@export var area_size := Vector2(17.5, 9.5) # X, Z
@export var min_speed := 3.0
@export var max_speed := 6.0

var bodies: Array[AnimatableBody3D] = []
var speeds: Array[float] = []
var x_offsets: Array[float] = []

func _ready():
	var original := get_child(0) as AnimatableBody3D
	bodies.append(original)

	# duplicate the AnimatableBody3D 
	for i in range(count - 1):
		var body := original.duplicate() as AnimatableBody3D
		add_child(body)
		bodies.append(body)

	# distribute evenly along X, with random speed
	for i in bodies.size():
		var x : float = lerp(
			-area_size.x,
			area_size.x,
			float(i) / float(max(1, count - 1))
		)
		x_offsets.append(x)
		speeds.append(randf_range(min_speed, max_speed))

func _physics_process(delta : float) -> void:
	for i in bodies.size():
		var body := bodies[i]
		body.position = Vector3(x_offsets[i], 0, body.position.z + speeds[i] * delta)

		# reverse direction at the extremities
		if abs(body.position.z) > area_size.y:
			speeds[i] = -speeds[i]
			body.position.z = max(min(body.position.z, area_size.y), -area_size.y)
