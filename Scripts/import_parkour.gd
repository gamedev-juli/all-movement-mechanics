@tool
extends Node3D

@export_tool_button("Import", "Callable")
var button = import


@export var bodies_enabled := true:
	set(value):
		bodies_enabled = value
		_set_bodies_enabled(value)


var material : Material = preload("res://Materials/mat_grid_orange.tres")
var material_water : Material = preload("res://Materials/mat_water.tres")
const OBJ_FOLDER := "res://Models/lvl5/"


func import() -> void:
	
	for child in get_children():
		remove_child(child)
		child.free()
	
	var dir := DirAccess.open(OBJ_FOLDER)
	if dir == null:
		push_error("Could not open folder: " + OBJ_FOLDER)
		return
	dir.list_dir_begin()
	
	while true:
		var filename := dir.get_next()
		if filename == "":
			break
		if dir.current_is_dir():
			continue
		if not filename.to_lower().ends_with(".obj"):
			continue
		
		var path := OBJ_FOLDER + filename
		print("Importing: ", path)
		
		var mesh := load(path) as ArrayMesh
		if mesh == null:
			push_error("Could not load OBJ: " + path)
			continue
		
		var mesh_name := filename.get_basename()
		var is_water := "water" in mesh_name
		
		var body := StaticBody3D.new() if not is_water else Node3D.new()
		body.name = mesh_name
		add_child(body)
		body.owner = get_tree().edited_scene_root
		
		
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material if not is_water else material_water
		if is_water:
			mesh_instance.transparency = 0.5
		body.add_child(mesh_instance)
		mesh_instance.owner = get_tree().edited_scene_root
		
		if not is_water:
			var collider := CollisionShape3D.new()
			collider.name = "CollisionShape3D"
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(mesh.get_faces())
			collider.shape = shape
			body.add_child(collider)
			collider.owner = get_tree().edited_scene_root

	dir.list_dir_end()
	print("Done.")


func _set_bodies_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is StaticBody3D or child is AnimatableBody3D:
			child.visible = enabled
			child.collision_layer = 1 if enabled else 0
			child.collision_mask = 1 if enabled else 0
