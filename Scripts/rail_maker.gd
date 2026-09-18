@tool
extends Node3D

@export var index : int = 0

@export var length : float = 10.0
@export_tool_button("Straight Path", "Callable")
var button0 = straight_path

@export var twist_angle : float = 0.0
@export_tool_button("Straight Twisted Path", "Callable")
var button1 = straight_twisted_path

@export var circle_radius : float = 4.0
@export var incline : float = 4.0
@export_tool_button("Circle Path", "Callable")
var button2 = circle

@export var loop_radius : float = 4.0
@export var offset : float = 0.0
@export var start_length : float = 10.0
@export var end_length : float = 20.0
@export_tool_button("Loop Path", "Callable")
var button3 = loop

var base_position := Vector3.ZERO
const suffix : Array[String] = ["", "2", "3", "4"]

func straight_path() -> void:
	base_position = get_node("Marker3D" + suffix[index]).global_position
	# Remove existing path
	var old_path := get_node_or_null("Path3D" + suffix[index])
	if old_path:
		print("deleting old")
		old_path.free()
	# create Path3D Node
	var path := Path3D.new()
	path.name = "Path3D" + suffix[index]
	add_child(path)
	path.global_position = base_position
	# define points along the curve
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0, 0, length))
	path.curve = curve
	# make it appear as a real scene child in the editor
	path.owner = get_tree().edited_scene_root
	# render using a CSGPolygon3D
	var polygon : CSGPolygon3D = get_node("CSGPolygon3D" + suffix[index])
	polygon.path_node = "../" + path.name

func straight_twisted_path() -> void:
	base_position = get_node("Marker3D" + suffix[index]).global_position
	# Remove existing path
	var old_path := get_node_or_null("Path3D" + suffix[index])
	if old_path:
		print("deleting old")
		old_path.free()
	# create Path3D Node
	var path := Path3D.new()
	path.name = "Path3D" + suffix[index]
	add_child(path)
	path.global_position = base_position
	# define points along the curve
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.set_point_tilt(0, 0.0)
	curve.add_point(Vector3(0, 0, length))
	curve.set_point_tilt(1, deg_to_rad(twist_angle))
	path.curve = curve
	# make it appear as a real scene child in the editor
	path.owner = get_tree().edited_scene_root
	# render using a CSGPolygon3D
	var polygon : CSGPolygon3D = get_node("CSGPolygon3D" + suffix[index])
	polygon.path_node = "../" + path.name

func circle() -> void:
	const circle_segments := 4
	base_position = get_node("Marker3D" + suffix[index]).global_position
	# remove existing path
	var old_path := get_node_or_null("Path3D" + suffix[index])
	if old_path:
		print("deleting old")
		old_path.free()
	# create Path3D Node
	var path := Path3D.new()
	path.name = "Path3D" + suffix[index]
	add_child(path)
	path.global_position = base_position
	# define points along the curve
	var curve := Curve3D.new()
	var angle_step := TAU / circle_segments
	var handle_length := 4.0 / 3.0 * tan(angle_step / 4.0) * circle_radius
	var incline_angle : float = deg_to_rad(incline)
	var marker_offset := Vector3(0,0,circle_radius)
	for i in range(circle_segments):
		var angle := i * angle_step
		var control_point := Vector3(-sin(angle), 0, cos(angle)) * handle_length
		curve.add_point(marker_offset + circle_radius * Vector3(cos(angle), 0, sin(angle)), -control_point, control_point)
		curve.set_point_tilt(i, incline_angle)
	curve.closed = true
	path.curve = curve
	# make it appear as a real scene child in the editor
	path.owner = get_tree().edited_scene_root
	# render using a CSGPolygon3D
	var polygon : CSGPolygon3D = get_node("CSGPolygon3D" + suffix[index])
	polygon.path_node = "../" + path.name

func loop() -> void:
	# vertical, with horizontal offset, and straight starts and ends
	
	const circle_segments := 4
	base_position = get_node("Marker3D" + suffix[index]).global_position
	# Remove existing path
	var old_path := get_node_or_null("Path3D" + suffix[index])
	if old_path:
		print("deleting old")
		old_path.free()
	# create Path3D Node
	var path := Path3D.new()
	path.name = "Path3D" + suffix[index]
	add_child(path)
	path.global_position = base_position
	# define points along the curve
	var curve := Curve3D.new()
	var angle_step := TAU / circle_segments
	var handle_length := 4.0 / 3.0 * tan(angle_step / 4.0) * circle_radius
	var marker_offset := Vector3(0,circle_radius,start_length)
	for i in range(circle_segments+1):
		var angle := i * angle_step
		var x := i * offset / circle_segments
		var control_point := Vector3(x, sin(angle), cos(angle)) * handle_length
		curve.add_point(marker_offset + circle_radius * Vector3(x, -cos(angle), sin(angle)), -control_point, control_point)
	curve.add_point(curve.get_point_position(0) - Vector3(0,0,start_length), Vector3.ZERO, Vector3.ZERO, 0)
	curve.add_point(curve.get_point_position(circle_segments+1) - Vector3(0,offset,-end_length))
	path.curve = curve
	# make it appear as a real scene child in the editor
	path.owner = get_tree().edited_scene_root
	# render using a CSGPolygon3D
	var polygon : CSGPolygon3D = get_node("CSGPolygon3D" + suffix[index])
	polygon.path_node = "../" + path.name
