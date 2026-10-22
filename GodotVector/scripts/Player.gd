extends CharacterBody2D

signal died

@export var CHARACTER_SCALE : float = 1.25:
	set(val):
		CHARACTER_SCALE = val
		if is_node_ready():
			_apply_character_scale()

var run_speed: float = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY = 1600.0
@export var CLIMB_SPEED : float = 90.0

const BOOST : float = 1.5
var boost_active : bool = false
var boost_multiplier : float = 1.0
var player_offset_x : float = 0.0

## Gravity Flip support ────────────────────────────────────────
## CG concept: reflection matrix [ 1 0 | 0 -1 ] applied to gravity vector.
## +1.0 = normal down, -1.0 = inverted (player runs on ceiling).
var gravity_scale    : float = 1.0
var _gravity_flipped : bool  = false

## Hitbox scale for Midpoint Shield power-up (1.0 = full size)
var _hitbox_scale      : float = 1.0
var _col_normal_orig   : Vector2 = Vector2(30.0, 80.0)
var _col_slide_orig    : Vector2 = Vector2(80.0, 40.0)

## Parkour Backflip (Space key) ────────────────────────────────
signal parkour_performed(trick_name: String, bonus_score: int)

var is_backflipping    : bool  = false
var backflip_rot       : float = 0.0
var backflip_progress  : float = 0.0
var _backflip_timer    : float = 0.0
var _can_air_backflip  : bool  = true
var _space_prev        : bool  = false
const BACKFLIP_DUR     : float = 0.52

var state = "run"
var stun_timer = 0.0

var is_mantling     : bool  = false
var mantle_progress : float = 0.0
var _mantle_timer   : float = 0.0
@export var MANTLE_DURATION : float = 0.33

var _prev_x     : float = 0.0    ## previous-frame x for stuck detection
var _stuck_time : float = 0.0    ## seconds with no forward progress
var _was_stuck  : bool  = false  ## for once-on-change debug print

var _climb_zones    : Array[Area2D] = []
var _climb_detector : Area2D
var _ui_fast_btn    : BaseButton

@onready var anim = $Sprite2D
@onready var dust = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide = $ColSlide
@onready var sfx_jump = $SfxJump
@onready var sfx_hit = $SfxHit
@onready var visual = $Visual

func _ready() -> void:
	if not InputMap.has_action("speed_boost"):
		InputMap.add_action("speed_boost")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SHIFT
		InputMap.action_add_event("speed_boost", ev)
	if not InputMap.has_action("trick"):
		InputMap.add_action("trick")
		var ev_sp := InputEventKey.new()
		ev_sp.keycode = KEY_SPACE
		InputMap.action_add_event("trick", ev_sp)
	_apply_character_scale()
	_setup_climb_detector()

func _get_fast_button() -> BaseButton:
	if _ui_fast_btn and is_instance_valid(_ui_fast_btn):
		return _ui_fast_btn
	if get_tree() and get_tree().root:
		var n = get_tree().root.find_child("FastButton", true, false)
		if n is BaseButton:
			_ui_fast_btn = n
			return _ui_fast_btn
	return null

func reset_boost() -> void:
	boost_active = false
	boost_multiplier = 1.0
	is_mantling = false
	mantle_progress = 0.0
	is_backflipping = false
	backflip_rot = 0.0
	backflip_progress = 0.0
	_can_air_backflip = true
	var btn := _get_fast_button()
	if btn:
		btn.button_pressed = false
	if Input.is_action_pressed("speed_boost"):
		Input.action_release("speed_boost")

func _setup_climb_detector() -> void:
	_climb_detector = Area2D.new()
	_climb_detector.name = "ClimbDetector"
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(40.0, 80.0)
	col.shape = shp
	col.position = Vector2(0.0, 10.0)
	_climb_detector.add_child(col)
	_climb_detector.area_entered.connect(_on_climb_area_entered)
	_climb_detector.area_exited.connect(_on_climb_area_exited)
	add_child(_climb_detector)

func _update_tower_legs_collision() -> void:
	var ignore : bool = (state == "slide" or state == "climb")
	var tower_legs := get_tree().get_nodes_in_group("tower_legs")
	if tower_legs.is_empty():
		return
	var exceptions := get_collision_exceptions()
	for node in tower_legs:
		if node is CollisionObject2D:
			var has_exc : bool = exceptions.has(node)
			if ignore and not has_exc:
				add_collision_exception_with(node)
			elif not ignore and has_exc:
				remove_collision_exception_with(node)

func _on_climb_area_entered(area: Area2D) -> void:
	if area.is_in_group("climbable") and not _climb_zones.has(area):
		_climb_zones.append(area)

func _on_climb_area_exited(area: Area2D) -> void:
	_climb_zones.erase(area)

func enter_climb_zone(area: Area2D) -> void:
	if not _climb_zones.has(area):
		_climb_zones.append(area)

func exit_climb_zone(area: Area2D) -> void:
	_climb_zones.erase(area)

func _apply_character_scale() -> void:
	if has_node("Visual"):
		var vis := get_node("Visual") as Node2D
		vis.scale = Vector2(CHARACTER_SCALE, CHARACTER_SCALE)
		vis.position.y = 50.0 * (1.0 - CHARACTER_SCALE)

	var s : float = 1.0 + (CHARACTER_SCALE - 1.0) * (0.15 / 0.25)
	if has_node("ColNormal"):
		var cn := get_node("ColNormal") as CollisionShape2D
		var shp_n := RectangleShape2D.new()
		shp_n.size = Vector2(30.0 * s, 80.0 * s)
		cn.shape = shp_n
		cn.position = Vector2(0.0, 50.0 - 40.0 * s)

	if has_node("ColSlide"):
		var cs := get_node("ColSlide") as CollisionShape2D
		var shp_s := RectangleShape2D.new()
		shp_s.size = Vector2(80.0 * s, 40.0 * s)
		cs.shape = shp_s
		cs.position = Vector2(0.0, 50.0 - 20.0 * s)

	if _climb_detector and _climb_detector.has_node("CollisionShape2D"):
		var cc := _climb_detector.get_node("CollisionShape2D") as CollisionShape2D
		var shp_c := RectangleShape2D.new()
		shp_c.size = Vector2(40.0 * s, 80.0 * s)
		cc.shape = shp_c
		cc.position = Vector2(0.0, 50.0 - 40.0 * s)



func _physics_process(delta):
	# Gravity applies when not on floor/ceiling (depending on flip) and not in climb state
	var _grounded : bool = (gravity_scale > 0.0 and is_on_floor()) or (gravity_scale < 0.0 and is_on_ceiling())
	if not _grounded and state != "climb":
		velocity.y += GRAVITY * gravity_scale * delta

	# Speed boost: Shift key or FAST button
	var _btn := _get_fast_button()
	var _btn_held : bool = _btn != null and (_btn.button_pressed)
	var _boost_on : bool = (Input.is_action_pressed("speed_boost") or _btn_held) \
		and state != "stun" and state != "dead"
	if _boost_on:
		boost_active = true
		boost_multiplier = BOOST
	else:
		boost_active = false
		boost_multiplier = 1.0
	var current_fwd_speed : float = run_speed * boost_multiplier

	# Check active climbable zone
	var can_climb : bool = false
	var active_zone : Area2D = null
	var i : int = _climb_zones.size() - 1
	while i >= 0:
		if not is_instance_valid(_climb_zones[i]):
			_climb_zones.remove_at(i)
		else:
			can_climb = true
			active_zone = _climb_zones[i]
		i -= 1

	if state == "stun":
		stun_timer -= delta
		velocity.x = 0.0
		# Jump cancels stun so player can leap over the obstacle
		if Input.is_action_just_pressed("jump") and is_on_floor():
			state = "run"
			stun_timer = 0.0
			modulate = Color(1, 1, 1)
			if sfx_jump:
				sfx_jump.play()
		if stun_timer <= 0:
			state = "run"
			modulate = Color(1, 1, 1)

	elif state == "climb":
		var top_y : float = -999999.0
		if active_zone:
			if active_zone.get_parent():
				top_y = active_zone.get_parent().global_position.y - 320.0
			elif active_zone.has_meta("tank_top_y"):
				top_y = active_zone.global_position.y + float(active_zone.get_meta("tank_top_y"))

		if not is_mantling:
			if top_y > -900000.0 and global_position.y <= top_y - 25.0:
				is_mantling = true
				_mantle_timer = MANTLE_DURATION
				mantle_progress = 0.0
				velocity = Vector2.ZERO
			elif not can_climb or not Input.is_action_pressed("jump"):
				state = "fall"
				modulate = Color(1, 1, 1)
			else:
				velocity.x = 0.0
				velocity.y = -CLIMB_SPEED
				modulate = Color(1, 1, 1)

		if is_mantling:
			_mantle_timer -= delta
			mantle_progress = clampf(1.0 - (_mantle_timer / MANTLE_DURATION), 0.0, 1.0)
			velocity.x = 0.0
			velocity.y = -60.0 * (1.0 - mantle_progress)
			if _mantle_timer <= 0.0:
				is_mantling = false
				mantle_progress = 0.0
				global_position.y = top_y - 50.0
				velocity.y = 0.0
				velocity.x = current_fwd_speed
				state = "run"
				modulate = Color(1, 1, 1)

	else:
		# Enter climb if overlapping climb zone and holding jump (Up)
		if can_climb and Input.is_action_pressed("jump") and state != "slide":
			state = "climb"
			is_mantling = false
			mantle_progress = 0.0
			velocity.x = 0.0
			velocity.y = -CLIMB_SPEED
			modulate = Color(1, 1, 1)
			if dust:
				dust.emitting = false
			if col_normal:
				col_normal.disabled = false
			if col_slide:
				col_slide.disabled = true
		else:
			velocity.x = current_fwd_speed
			var _on_ground : bool = (gravity_scale > 0.0 and is_on_floor()) or (gravity_scale < 0.0 and is_on_ceiling())
			if Input.is_action_pressed("slide") and _on_ground:
				state = "slide"
				if col_normal:
					col_normal.disabled = true
				if col_slide:
					col_slide.disabled = false
				if dust:
					dust.emitting = true
			else:
				if state == "slide":
					state = "run"
					if col_normal:
						col_normal.disabled = false
					if col_slide:
						col_slide.disabled = true
					if dust:
						dust.emitting = false

			# ── Parkour Backflip (Space key) ─────────────────────
			var space_down : bool = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("trick")
			var space_just_pressed : bool = space_down and not _space_prev
			_space_prev = space_down

			if space_just_pressed:
				trigger_backflip()

			# Regular Up Arrow jump
			if Input.is_action_just_pressed("jump") and _on_ground and state != "slide" and not is_backflipping:
				velocity.y = JUMP_VELOCITY * gravity_scale
				if sfx_jump:
					sfx_jump.play()

			# Update backflip rotation
			if is_backflipping:
				_backflip_timer -= delta
				backflip_progress = clampf(1.0 - (_backflip_timer / BACKFLIP_DUR), 0.0, 1.0)
				# 360 degree rotation (TAU radians) in backflip direction
				backflip_rot = -backflip_progress * TAU * signf(gravity_scale)
				if _backflip_timer <= 0.0:
					is_backflipping = false
					backflip_rot = 0.0
					backflip_progress = 0.0

			var _grounded2 : bool = (gravity_scale > 0.0 and is_on_floor()) or (gravity_scale < 0.0 and is_on_ceiling())
			if _grounded2:
				_can_air_backflip = true
				if is_backflipping and backflip_progress > 0.7:
					is_backflipping = false
					backflip_rot = 0.0
					backflip_progress = 0.0

			if not _grounded2:
				if velocity.y * gravity_scale < 0:
					state = "jump"
				else:
					state = "fall"
			elif state != "slide":
				state = "run"

	var rect_x = 0
	if state == "run":
		var _anim_div : int = 7 if boost_multiplier > 1.0 else 10
		rect_x = (Engine.get_frames_drawn() / _anim_div % 2) * 100
	elif state == "jump" or state == "fall":
		rect_x = 200
	elif state == "slide":
		rect_x = 300
	elif state == "climb":
		rect_x = (Engine.get_frames_drawn() / 8 % 2) * 100

	if anim:
		anim.region_rect = Rect2(rect_x, 0, 100, 100)
	_update_tower_legs_collision()
	move_and_slide()
	if is_on_wall():
		velocity.x = 0.0

	# Stuck detection: no forward progress while on floor
	var _dx : float = global_position.x - _prev_x
	_prev_x = global_position.x
	if _dx < 1.0 and is_on_floor() and state != "dead" and state != "climb":
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	var _sn : bool = is_player_stuck()
	if _sn != _was_stuck:
		print("[Player] stuck=%s  stuck_time=%.2f  state=%s" % [str(_sn), _stuck_time, state])
		_was_stuck = _sn

	if global_position.y > 900 and state != "dead":
		reset_boost()
		state = "dead"
		set_physics_process(false)
		await get_tree().create_timer(0.5).timeout
		died.emit()
		return



## True when the player cannot make forward progress (physical block OR stun).
func is_player_stuck() -> bool:
	return _stuck_time >= 0.15 or state == "stun"

func stun():
	reset_boost()
	if state != "stun":
		state = "stun"
		stun_timer = 1.0
		if sfx_hit:
			sfx_hit.play()
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(1.0).timeout
		modulate = Color(1, 1, 1)

## ── Gravity Flip ─────────────────────────────────────────────
## Called by GravityZone signal. Flips gravity and the visual node.
## CG: applies reflection [ 1 0 | 0 -1 ] to the physics gravity vector.
func flip_gravity(inverted: bool) -> void:
	if _gravity_flipped == inverted:
		return
	_gravity_flipped = inverted
	gravity_scale    = -1.0 if inverted else 1.0
	# Flip the visual node upside-down via scale.y reflection
	if visual:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(visual, "scale:y",
			-CHARACTER_SCALE if inverted else CHARACTER_SCALE, 0.25)
	# Give an immediate velocity impulse to launch toward the new ground
	velocity.y = -220.0 if inverted else 220.0

## ── Midpoint Shield hitbox scale ─────────────────────────────
## Tweens both collision shapes to original_size * scale_factor.
## CG concept: midpoint subdivision -- halving the shape.
func set_hitbox_scale(scale_factor: float) -> void:
	if not col_normal or not col_slide:
		return
	_hitbox_scale = scale_factor
	var s : float = 1.0 + (CHARACTER_SCALE - 1.0) * (0.15 / 0.25)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	if col_normal.shape is RectangleShape2D:
		var target_sz := _col_normal_orig * s * scale_factor
		tw.tween_property(col_normal.shape, "size", target_sz, 0.3)
	if col_slide.shape is RectangleShape2D:
		var target_sz := _col_slide_orig * s * scale_factor
		tw.tween_property(col_slide.shape, "size", target_sz, 0.3)

## ── Parkour Backflip Trick ───────────────────────────────────
## Can be triggered from ground (acrobatic spring) or mid-air (aerial flip).
## Applies full 360-degree rotation matrix and emits bonus trick score.
func trigger_backflip() -> bool:
	if is_backflipping or state == "dead" or state == "stun":
		return false
	var _on_ground : bool = (gravity_scale > 0.0 and is_on_floor()) or (gravity_scale < 0.0 and is_on_ceiling())
	if _on_ground and state != "slide":
		is_backflipping = true
		_backflip_timer = BACKFLIP_DUR
		backflip_progress = 0.0
		backflip_rot = 0.0
		velocity.y = JUMP_VELOCITY * 1.12 * gravity_scale
		state = "jump"
		_can_air_backflip = true
		if sfx_jump:
			sfx_jump.play()
		parkour_performed.emit("BACKFLIP!", 100)
		return true
	elif not _on_ground and _can_air_backflip and state != "climb":
		is_backflipping = true
		_backflip_timer = BACKFLIP_DUR
		backflip_progress = 0.0
		backflip_rot = 0.0
		_can_air_backflip = false
		state = "jump"
		velocity.y = minf(velocity.y, -460.0 * gravity_scale) if gravity_scale > 0.0 else maxf(velocity.y, 460.0 * -gravity_scale)
		if sfx_jump:
			sfx_jump.play()
		parkour_performed.emit("AIR FLIP!", 150)
		return true
	return false
