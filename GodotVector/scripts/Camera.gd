## Camera.gd
## Locks vertical camera position to provide a rock-solid, stable ground baseline.
## Tracks player forward X progress, but prevents vertical jumping, flips, and
## stumbles from causing the ground to dip or drop below the viewport.
## Also supports a smooth 180-degree rotation when gravity is flipped.
extends Camera2D

@export var follow_offset_x  : float = 300.0
@export var baseline_y       : float = 390.0
@export var flip_speed       : float = 5.0   ## lerp speed for gravity-flip rotation

var target : CharacterBody2D = null

## Gravity flip rotation state
var _target_rotation : float = 0.0   ## 0 = normal, PI = flipped
var _cam_rotation    : float = 0.0

func _ready() -> void:
	top_level = true
	position_smoothing_enabled = false
	_find_target()
	global_position.y = baseline_y
	if target:
		global_position.x = target.global_position.x + follow_offset_x
	make_current()

func _find_target() -> void:
	if not target:
		var parent = get_parent()
		if parent is CharacterBody2D:
			target = parent
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody2D
	if not target and get_tree() and get_tree().root:
		target = get_tree().root.find_child("Player", true, false) as CharacterBody2D

func _process(delta: float) -> void:
	_update_position()
	_update_rotation(delta)

func _physics_process(delta: float) -> void:
	_update_position()
	_update_rotation(delta)

func _update_position() -> void:
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return

	# Horizontal tracks player forward progress
	global_position.x = target.global_position.x + follow_offset_x

	# Vertical stays completely locked at ground baseline: ground never dips on screen
	global_position.y = baseline_y

## Smoothly lerp camera rotation toward target (0 or PI for gravity flip).
func _update_rotation(delta: float) -> void:
	_cam_rotation = lerp_angle(_cam_rotation, _target_rotation, delta * flip_speed)
	rotation = _cam_rotation

## Called by GravityZone signal (via LevelManager or PowerUpManager).
## Rotates camera 180 degrees to match world inversion.
func set_gravity_flipped(inverted: bool) -> void:
	_target_rotation = PI if inverted else 0.0
