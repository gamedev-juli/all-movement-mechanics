@tool
extends Node3D

@export_tool_button("Import", "Callable")
var import_button = import_from_blender

@onready var polygon_template : CSGPolygon3D = $CSGPolygon3D_template

const IMPORT_FILE := "res://Models/lvl3_rails/rail.json"


func import_from_blender() -> void:
	var file := FileAccess.open(IMPORT_FILE, FileAccess.READ)
	if file == null:
		push_error("Could not open: " + IMPORT_FILE)
		return
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		push_error("Invalid JSON")
		return
	
	# remove previously imported paths
	for child in get_children(): 
		if child == polygon_template:
			continue
		child.free()
	
	# create one Path3D per Blender spline
	for spline_index in range(data.splines.size()):
		var spline_data = data.splines[spline_index]
		
		var path := Path3D.new()
		path.name = "Path3D%d" % spline_index
		
		var curve := Curve3D.new()
		for i in range(spline_data.points.size()):
			var point = spline_data.points[i]
			var pos := blender_to_godot(point.position)
			var handle_left := blender_to_godot(point.handle_left)
			var handle_right := blender_to_godot(point.handle_right)
			curve.add_point(pos, handle_left - pos, handle_right - pos)
			curve.set_point_tilt(i, point.tilt)
		curve.closed = spline_data.closed
		path.curve = curve
		add_child(path)
		path.owner = get_tree().edited_scene_root
		
		var polygon : CSGPolygon3D = polygon_template.duplicate()
		polygon.name = "CSGPolygon3D" + str(spline_index)
		add_child(polygon)
		polygon.owner = get_tree().edited_scene_root
		polygon.path_node = NodePath("../" + path.name)
		polygon.use_collision = true
		


func blender_to_godot(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])
