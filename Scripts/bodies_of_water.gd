extends Node3D

@onready var character: CharacterBody3D = $"../CharacterBody3D"

var areas : Array[Area3D]


func _ready():
	for area in get_children():
		if area is Area3D :
			if area.visible:
				areas.append(area)


func _physics_process(_delta: float) -> void:
	for area in areas:
		if area.overlaps_body(character):
			character.next_is_in_water = true
			return
	character.next_is_in_water = false
