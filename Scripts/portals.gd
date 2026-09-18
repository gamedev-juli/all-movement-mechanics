extends Node3D

@onready var character: CharacterBody3D = $"../CharacterBody3D"
@onready var doppel: Node3D = $Doppelganger
@onready var portal0 : Node3D = $Portal0
@onready var portal1 : Node3D = $Portal1
@onready var mesh0 : MeshInstance3D = $Portal0/MeshInstance3D
@onready var mesh1 : MeshInstance3D = $Portal1/MeshInstance3D

@export var bounds_portal0 : Array[CollisionShape3D]
@export var bounds_portal1 : Array[CollisionShape3D]

# Node and CollisionShape where the portal is attached to
var surface_portal0 : StaticBody3D = null
var surface_portal1 : StaticBody3D = null
var collider_portal0 : CollisionShape3D = null
var collider_portal1 : CollisionShape3D = null

var is_close_to_portal0 := false
var is_close_to_portal1 := false
var prev_is_close_to_portal0 := false
var prev_is_close_to_portal1 := false

var enabled0 := false
var enabled1 := false
var both_enabled := false
var same_collider := false

const FLIPXY := Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))
const W := 2.0 # width of portal
const H := 3.0 # height of portal

func _ready():
	portal0.visible = false
	portal1.visible = false


func _physics_process(_delta: float) -> void:
	# update colliders when entering or exiting Area3D around portals
	if not both_enabled:
		return
	
	# check if close to portal0
	is_close_to_portal0 = true
	var character_local_portal0 : Vector3 = portal0.global_transform.affine_inverse() * character.position
	if character_local_portal0.y > 2 or character_local_portal0.y < 0:
		is_close_to_portal0 = false
	elif abs(character_local_portal0.x) > W * 0.5 - 0.05:
		is_close_to_portal0 = false
	elif abs(character_local_portal0.z) > H * 0.5 - 0.05:
		is_close_to_portal0 = false
	
	# idem portal1
	is_close_to_portal1 = true
	var character_local_portal1 : Vector3 = portal1.global_transform.affine_inverse() * character.position
	if character_local_portal1.y > 2 or character_local_portal1.y < 0:
		is_close_to_portal1 = false
	elif abs(character_local_portal1.x) > W * 0.5 - 0.05:
		is_close_to_portal1 = false
	elif abs(character_local_portal1.z) > H * 0.5 - 0.05:
		is_close_to_portal1 = false
	
	var going_through : bool = (not is_close_to_portal0 and prev_is_close_to_portal0 and character_local_portal0.y < 0) or (not is_close_to_portal1 and prev_is_close_to_portal1  and character_local_portal1.y < 0)
	
	if going_through or is_close_to_portal0 or is_close_to_portal1:
		# allow access through the portals
		collider_portal0.set_deferred("disabled", true) 
		collider_portal1.set_deferred("disabled", true) 
		for bound in bounds_portal0:
			bound.set_deferred("disabled", false)
		for bound in bounds_portal1:
			bound.set_deferred("disabled", false)
	else:
		# dont allow access through the portals
		collider_portal0.set_deferred("disabled", false) 
		collider_portal1.set_deferred("disabled", false) 
		for bound in bounds_portal0:
			bound.set_deferred("disabled", true)
		for bound in bounds_portal1:
			bound.set_deferred("disabled", true)

	# copy the character if going through portal
	doppel.visible = false
	if going_through or is_close_to_portal0 or is_close_to_portal1:
		var from_portal := portal0 if is_close_to_portal0 else portal1
		var to_portal := portal1 if is_close_to_portal0 else portal0
		if going_through:
			from_portal = portal0 if prev_is_close_to_portal0 else portal1
			to_portal = portal1 if prev_is_close_to_portal0 else portal0
		
		# check if going through portal
		var transform_local : Transform3D = from_portal.transform.affine_inverse() * character.transform
		#if transform_local.origin.y < 0:
		if going_through:
			character.do_portal_swap(from_portal.global_transform, to_portal.global_transform)
		
		
		elif abs(transform_local.origin.y) < 0.5:
			transform_local.basis = FLIPXY * transform_local.basis
			transform_local.origin *= Vector3(-1, -1, 1)
			doppel.global_transform = to_portal.global_transform * transform_local
			doppel.scale = Vector3(character.character_scale,character.character_scale,character.character_scale)
			doppel.visible = true
			
	prev_is_close_to_portal0 = is_close_to_portal0
	prev_is_close_to_portal1 = is_close_to_portal1
	


func enable_portal(idx : int, new_transform : Transform3D, surface : StaticBody3D, new_collider : CollisionShape3D) -> void:
	if idx == 0:
		enabled0 = true
		portal0.visible = true
		portal0.transform = new_transform
		surface_portal0 = surface
		collider_portal0 = new_collider
		mesh0.transparency = 0.5 if not both_enabled else 0.0
	else:
		enabled1 = true
		portal1.visible = true
		portal1.transform = new_transform
		surface_portal1 = surface
		collider_portal1 = new_collider
		mesh1.transparency = 0.5 if not both_enabled else 0.0
	
	both_enabled = enabled0 and enabled1
	if both_enabled:
		mesh0.transparency = 0.0
		mesh1.transparency = 0.0
		same_collider = collider_portal0 == collider_portal1


#func disable_portal(idx : int) -> void:
	#if idx == 0:
		#enabled0 = false
		#portal0.visible = false
		#if collider_portal0.disabled:
			#collider_portal0.set_deferred("disabled", false)
		#for bound in bounds_portal0:
			#bound.set_deferred("disabled", true)
		#collider_portal0 = null
		#surface_portal0 = null
	#else:
		#enabled1 = false
		#portal1.visible = false
		#if collider_portal1.disabled:
			#collider_portal1.set_deferred("disabled", false)
		#for bound in bounds_portal1:
			#bound.set_deferred("disabled", true)
		#collider_portal1 = null
		#surface_portal1 = null


func update_portal(shoot_portal0 : bool, shoot_portal1 : bool, portal_global_position : Vector3, surface_normal : Vector3, surface : StaticBody3D) -> void:
	var space_state := get_world_3d().direct_space_state
	
	portal_global_position += surface_normal * 0.001 # z-fighting
	var portal_global_basis : Basis
	if abs(surface_normal.dot(character.AXES.y)) < cos(deg_to_rad(20)): # portal on wall
		var new_y : Vector3 = surface_normal.normalized()
		var new_z : Vector3 = (-character.AXES.y).slide(new_y).normalized()
		var new_x : Vector3 = new_y.cross(new_z) # right-handed
		portal_global_basis = Basis(new_x, new_y, new_z)
	else: # portal on ground or ceiling
		# choose rotation around surface_normal so that new_z is aligned to x or z axis and points towards character
		var desired_z : Vector3 = (character.position - portal_global_position).normalized().slide(surface_normal)
		var new_y := surface_normal.normalized()
		var z_back : Vector3 = character.AXES.z.slide(new_y).normalized()
		var z_right : Vector3 = character.AXES.x.slide(new_y).normalized()
		var alignment_z_back := desired_z.dot(z_back)
		var alignment_z_right := desired_z.dot(z_right)
		var new_z : Vector3 = z_back * sign(alignment_z_back) if abs(alignment_z_back) > abs(alignment_z_right) else z_right * sign(alignment_z_right)
		if new_y.dot(character.AXES.y) < 0: # ceiling
			new_z = -new_z
		var new_x := new_y.cross(new_z) # right-handed
		portal_global_basis = Basis(new_x, new_y, new_z)
	
	# check if the area is flat and unobstructed using two BoxShape3Ds
	var shape := BoxShape3D.new()
	var offset := 0.25
	var portal_plane_mesh : PlaneMesh = mesh0.mesh
	shape.size = Vector3(portal_plane_mesh.size.x, offset * 2, portal_plane_mesh.size.y) # NOTE thin colliders dont work for some reason
	var query := PhysicsShapeQueryParameters3D.new()
	query.exclude = [character.get_rid()]
	query.shape = shape
	query.transform = Transform3D(portal_global_basis, portal_global_position + surface_normal * (offset + 0.1))
	var hit = space_state.intersect_shape(query)
	if hit.size() != 0:
		return
	query.transform = Transform3D(portal_global_basis, portal_global_position - surface_normal * (offset + 0.1))
	hit = space_state.intersect_shape(query)
	if hit.size() != 0:
		return
	
	# check if portals would be overlapping
	var new_transform := Transform3D(portal_global_basis, portal_global_position)
	var new_collider : CollisionShape3D = surface.get_node("CollisionShape3D")
	if (shoot_portal1 and enabled0) or (shoot_portal0 and enabled1):
		var other_portal_local_pos : Vector3 = new_transform.affine_inverse() * (portal0 if shoot_portal1 else portal1).global_position
		var is_same_collider : bool = (collider_portal0 if shoot_portal1 else collider_portal1) == new_collider
		var same_normal : bool =  new_transform.basis.y.dot((portal0 if shoot_portal1 else portal1).basis.y) > 0.99
		var too_close : bool = abs(other_portal_local_pos.x) < W + 0.1 and abs(other_portal_local_pos.z) < H + 0.1
		if is_same_collider and same_normal and too_close:
			return
		
	# check if portal is still on surface in corners
	for corner_local in [Vector3(-W*0.5,0,-H*0.5), Vector3(W*0.5,0,-H*0.5), Vector3(-W*0.5,0,H*0.5), Vector3(W*0.5,0,H*0.5)]:
		var corner_global : Vector3 = new_transform * corner_local
		var raycast := PhysicsRayQueryParameters3D.create(
			corner_global + surface_normal * 0.01,
			corner_global - surface_normal * 0.02
		)
		hit = space_state.intersect_ray(raycast)
		if hit.is_empty():
			return
		elif hit.collider != surface:
			return
		
	# portal is valid
	enable_portal(
		0 if shoot_portal0 else 1, 
		Transform3D(portal_global_basis, portal_global_position), 
		surface,
		new_collider)
