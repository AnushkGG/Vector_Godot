extends Node2D
## AI-controlled chaser – world-space Node2D sibling of Player under Main.
## Moves only in _physics_process. Draws own running/jump/slide/aim silhouette + gun.

signal caught   ## emitted once after 0.3 s aim pose (via call_deferred for flash)

# ── Exported tunables ─────────────────────────────────────────
@export var CHARACTER_SCALE : float = 1.25  ## visual scale factor (about feet)
@export var FOLLOW_GAP    : float = 260.0   ## gap (px) while player runs freely
@export var CLOSE_SPEED   : float = 280.0   ## px/s closing speed when player is stuck (~0.7s)
@export var RECOVER_SPEED : float = 1.8     ## lerp rate back to FOLLOW_GAP
@export var CATCH_DISTANCE: float = 40.0    ## gap that starts the aim pose + game over
@export var LOOKAHEAD_TIME: float = 0.35    ## seconds of travel to scan ahead for obstacles

var _is_banished  : bool  = false
var _banish_timer : float = 0.0

func _col_scale() -> float:
	return 1.0 + (CHARACTER_SCALE - 1.0) * (0.15 / 0.25)

func _get_follow_gap() -> float:
	return FOLLOW_GAP * _col_scale()

func _get_catch_distance() -> float:
	return CATCH_DISTANCE * _col_scale()

func _get_edge_margin() -> float:
	return EDGE_MARGIN * CHARACTER_SCALE


# ── Physics (matches Player.gd exactly) ───────────────────────
const JUMP_VEL      : float = -700.0
const GRAVITY_CONST : float = 1600.0
## Center-y when on ground (feet land at GROUND_Y = 560 = center + FOOT_Y 50)
const GROUND_CENTER : float = 510.0

# ── Screen layout ─────────────────────────────────────────────
## Camera2D.position.x offset on Player (Main.tscn: Vector2(300,-120))
const CAM_OFFSET_X : float = 300.0
## Min px from screen-left to chaser draw origin
const EDGE_MARGIN  : float = 40.0

# ── Silhouette constants (matches PlayerVisual.gd proportions) ──
const C          : Color = Color(0.0, 0.0, 0.0)

# ── Clothing colours (police) ─────────────────────────────────
const SHIRT     : Color = Color(0.18, 0.44, 0.88)   # #2f6fe0 bright police blue
const BADGE     : Color = Color(1.00, 0.84, 0.00)   # yellow badge dot
const PANTS     : Color = Color(0.11, 0.18, 0.42)   # #1b2f6b navy trousers
const BELT      : Color = Color(0.08, 0.08, 0.08)   # black belt line
const BUCKLE    : Color = Color(0.85, 0.85, 0.85)   # silver belt buckle
const CAP       : Color = Color(0.11, 0.18, 0.42)   # #1b2f6b navy police cap
const CAP_PEAK  : Color = Color(0.05, 0.05, 0.05)   # black peak
const FOOT_Y     : float = 50.0
const UPR_LEG    : float = 22.0
const LWR_LEG    : float = 22.0
const HIP_Y      : float = FOOT_Y - UPR_LEG - LWR_LEG   # = 6.0
const TORSO_H    : float = 28.0
const SHO_Y      : float = HIP_Y - TORSO_H               # = -22.0
const NECK_H     : float = 4.0
const HEAD_R     : float = 8.5
const UPR_ARM    : float = 14.0
const LWR_ARM    : float = 12.0
const ARM_SWING  : float = 0.75
const ELBOW_BASE : float = 1.25
const SHO_HW     : float = 8.0
const HIP_HW     : float = 5.5
const TH_THIGH   : float = 7.0
const TH_CALF    : float = 5.5
const TH_ARM_U   : float = 5.0
const TH_ARM_L   : float = 4.0
const TH_FOOT    : float = 6.0

# ── Runtime state ─────────────────────────────────────────────
var _player      : CharacterBody2D
var _spawner     : Node2D
var _gap         : float   = 260.0
var _chaser_y    : float   = GROUND_CENTER
var _vel_y       : float   = 0.0
var _on_ground   : bool    = true
var _ai_state    : String  = "run"
var _slide_timer : float   = 0.0
var _grab_timer  : float   = 0.0
var _caught_once : bool    = false
var _anim_time   : float   = 0.0
var _prev_stuck  : bool    = false
var _gun_tip     : Vector2 = Vector2.ZERO
var _show_flash  : bool    = false
var _jump_time   : float   = 0.0
var _land_squash : float   = 0.0
var _slide_blend : float   = 0.0

func _ready() -> void:
	z_index = 2
	_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	_spawner = get_parent().get_node_or_null("Spawner")
	if not has_node("Visual"):
		var vis := preload("res://scripts/ChaserVisual.gd").new()
		vis.name = "Visual"
		add_child(vis)
	reset()

func reset(p: CharacterBody2D = null) -> void:
	if p:
		_player = p
	_gap = _get_follow_gap()
	_chaser_y = GROUND_CENTER
	_vel_y = 0.0
	_on_ground = true
	_ai_state = "run"
	_slide_timer = 0.0
	_grab_timer = 0.0
	_caught_once = false
	_anim_time = 0.0
	_jump_time = 0.0
	_land_squash = 0.0
	_slide_blend = 0.0
	_show_flash = false
	_prev_stuck = false
	visible = true
	set_physics_process(true)
	set_process(true)
	_is_banished  = false
	_banish_timer = 0.0
	modulate      = Color(1, 1, 1, 1)
	if _player:
		global_position = Vector2(_player.global_position.x - _gap, _chaser_y)

func banish(duration: float = 4.0) -> void:
	_is_banished  = true
	_banish_timer = duration
	_gap          = _get_follow_gap() + 700.0
	_ai_state     = "run"
	modulate      = Color(0.2, 1.0, 0.4, 0.35)

func is_banished() -> bool:
	return _is_banished

func deactivate() -> void:
	visible = false
	_caught_once = true
	set_physics_process(false)
	set_process(false)

func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	if "state" in _player and _player.state == "dead":
		return
	if _caught_once:
		return

	var stuck : bool = false
	if _player.has_method("is_player_stuck"):
		stuck = _player.is_player_stuck()
	elif "state" in _player:
		stuck = _player.state == "stun"

	if stuck != _prev_stuck:
		_prev_stuck = stuck

	if _is_banished:
		_banish_timer -= delta
		var follow_g : float = _get_follow_gap()
		_gap = maxf(_gap, follow_g + 500.0)
		if _banish_timer <= 0.0:
			_is_banished = false
			modulate = Color(1, 1, 1, 1)

	# Gap update
	if _ai_state != "grab":
		var catch_d  : float = _get_catch_distance()
		var follow_g : float = _get_follow_gap()
		if _is_banished:
			pass
		elif stuck:
			_gap = maxf(catch_d, _gap - CLOSE_SPEED * delta)
		else:
			_gap = move_toward(_gap, follow_g, RECOVER_SPEED * delta * 60.0)

		if not _is_banished and _gap <= catch_d:
			_ai_state = "grab"
			_grab_timer = 0.3

	if _ai_state == "grab":
		_grab_timer -= delta
		if _grab_timer <= 0.0 and not _caught_once:
			_caught_once = true
			_show_flash = true
			queue_redraw()
			call_deferred("_emit_caught")

	var p_speed : float = _player.run_speed if "run_speed" in _player else 500.0
	var speed   : float = p_speed

	if _ai_state != "grab":
		if not _on_ground:
			_vel_y += GRAVITY_CONST * delta
			_chaser_y += _vel_y * delta
			if _vel_y > 0.0:
				_ai_state = "fall"
			if _chaser_y >= GROUND_CENTER:
				_chaser_y = GROUND_CENTER
				_vel_y = 0.0
				_on_ground = true
				_land_squash = 1.0
				_jump_time = 0.0
				var chaser_x : float = _player.global_position.x - _gap
				if _should_slide_on_landing(chaser_x):
					_ai_state = "slide"
					_slide_timer = 0.55
				else:
					_ai_state = "run"
		elif _ai_state == "slide":
			_slide_timer -= delta
			if _slide_timer <= 0.0:
				_ai_state = "run"
		else:
			_ai_scan(speed)

	var desired_x : float = _player.global_position.x - _gap
	var cam_left  : float = _player.global_position.x + CAM_OFFSET_X - 640.0
	var min_x     : float = cam_left + _get_edge_margin()
	global_position = Vector2(maxf(desired_x, min_x), _chaser_y)

func _emit_caught() -> void:
	caught.emit()

func _ai_scan(speed: float) -> void:
	if not _spawner:
		return
	var chaser_x  : float = _player.global_position.x - _gap
	var look_dist : float = speed * LOOKAHEAD_TIME
	var raw_zones = _spawner.get("_active_zones")
	if not raw_zones or not (raw_zones is Array):
		return
	var zones : Array = raw_zones

	var best_left : float      = INF
	var best_info : Dictionary = {}
	for info : Dictionary in zones:
		var z       : Rect2 = info["rect"]
		var z_left  : float = z.position.x
		var z_right : float = z.position.x + z.size.x
		if z_right > chaser_x and z_left < chaser_x + look_dist:
			if z_left < best_left:
				best_left = z_left
				best_info = info

	if best_info.is_empty():
		return

	if best_info.get("is_beam", false):
		var bw : float = best_info["rect"].size.x
		_ai_state    = "slide"
		_slide_timer = maxf(bw / speed + 0.2, 0.4)
	else:
		_do_jump()

func _do_jump() -> void:
	if _on_ground:
		_vel_y       = JUMP_VEL
		_on_ground   = false
		_ai_state    = "jump"
		_jump_time   = 0.0
		_land_squash = 0.0

func _should_slide_on_landing(chaser_x: float) -> bool:
	if not _spawner:
		return false
	var zones : Array = _spawner.get("_active_zones")
	for info : Dictionary in zones:
		var is_beam : bool  = info.get("is_beam", false)
		var kind    : int   = info.get("kind", 0)
		var z       : Rect2 = info["rect"]
		if is_beam and chaser_x >= z.position.x and chaser_x <= z.position.x + z.size.x:
			return true
		if kind == 6:
			var bs : float = z.position.x + 275.0
			if chaser_x >= bs and chaser_x <= bs + 220.0:
				return true
	return false

func _process(delta: float) -> void:
	if not visible:
		return
	if _ai_state == "run":
		_anim_time += delta * 7.5
	elif _ai_state == "slide":
		_anim_time += delta * 10.0

	if not _on_ground:
		_jump_time += delta
	_land_squash = maxf(0.0, _land_squash - delta / 0.12)

	if _ai_state == "slide":
		_slide_blend = clampf(_slide_blend + delta * 12.0, 0.0, 1.0)
	else:
		_slide_blend = 0.0

	queue_redraw()

func _draw() -> void:
	# Visual rendering is handled by child Visual node (ChaserVisual.gd)
	pass
