extends Node3D

@onready var character : CharacterBody3D = $"../CharacterBody3D"

var attachment_point := Vector3.ZERO
var attachment_point2 := Vector3.ZERO
var is_slingshot := false

var material : Material = StandardMaterial3D.new()
var immediate_mesh := ImmediateMesh.new()
var mesh_instance := MeshInstance3D.new()
var to_local_space : Transform3D

func _ready() -> void:
	mesh_instance.mesh = immediate_mesh
	add_child(mesh_instance)
	to_local_space = mesh_instance.global_transform.affine_inverse()
	mesh_instance.visible = false
	material.albedo_color = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _process(_delta: float) -> void:
	if not mesh_instance.visible:
		return
	
	var v0 := to_local_space * attachment_point
	var v1 := to_local_space * character.position
	
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(v0)
	immediate_mesh.surface_add_vertex(v1)
	if is_slingshot:
		immediate_mesh.surface_add_vertex(v1)
		immediate_mesh.surface_add_vertex(to_local_space * attachment_point2)
	immediate_mesh.surface_end()


func toggle_visibility(should_be_visible : bool, new_attachment_point : Vector3 = Vector3.ZERO, new_is_slingshot : bool = false, new_attachment_point2 : Vector3 = Vector3.ZERO) -> void:
	if should_be_visible:
		attachment_point = new_attachment_point
		if new_is_slingshot:
			is_slingshot = true
			attachment_point2 = new_attachment_point2
	else:
		is_slingshot = false
	mesh_instance.visible = should_be_visible
