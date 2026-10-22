## NeonGrid.gd
## Deprecated / removed in favor of ZoomClippingController
extends Node2D

func _ready() -> void:
	visible = false
	set_process(false)
	set_process_input(false)