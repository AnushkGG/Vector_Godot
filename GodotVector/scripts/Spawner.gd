extends Node2D
class_name Spawner

## Center-to-center spacing of the continuous coin trail (px).
@export var COIN_SPACING    : float = 160.0
## Probability (0-1) that a gap will contain an obstacle cluster
@export var spawn_rate      : float = 0.78
## Minimum pixel gap between obstacle clusters
@export var min_gap         : float = 520.0
## Maximum pixel gap between obstacle clusters
@export var max_gap         : float = 1050.0
## Diamonds to place per run (set by LevelManager via set_difficulty)
@export var diamonds_per_run: int   = 4
## Clearance margin added around obstacles for diamond placement (px)
@export var obs_clearance   : float = 50.0
## Approximate distance between diamonds, measured in multiples of COIN_SPACING.
## ~11 means roughly one diamond every 11 coins of trail distance (≈1760 px at 160 spacing).
@export var DIAMOND_INTERVAL : int = 11

const GROUND_Y : float = 560.0
## Base height of the coin trail: 55 px above ground — collectible while running.
const TRAIL_Y  : float = GROUND_Y - 55.0   # = 505
## How many px before/after an obstacle the arc approach begins.
const ARC_PAD  : float = 100.0

signal collectible_picked(kind: int)

enum ObsType { LOW_BLOCK, TALL_WALL, SOLID_BLACK, DOUBLE_BLOCK, MOVING_OBS, HIGH_LOW_COMBO, AC_ROW, VENT_UNIT, WATER_TOWER }

# ── State ─────────────────────────────────────────────────────
var _next_x              : float = 900.0
var _coin_x              : float = 900.0   # x of the next trail coin to place
var _diamonds_left       : int   = 0
var _player              : CharacterBody2D
var _last_diamond_x      : float = 0.0   # world-x of last placed diamond
var _difficulty_level    : int   = 1
var _speed_ref           : float = 500.0
var _alt_black_obs       : bool  = false   ## alternates between WaterTank (40x70) and BlackDrum (50x40)

var _powerup_cycle_idx   : int   = 0
var _last_powerup_x      : float = 0.0
var _last_gravity_zone_x : float = -9999.0

## Per-obstacle zone records for coin-trail height calculation.
## Each element is a Dictionary: { rect:Rect2, kind:int, top_y:float, is_beam:bool }
var _active_zones : Array = []

# ── Preloads ──────────────────────────────────────────────────
var _tex_tall   := preload("res://assets/obs_tall.png")
var _tex_box    := preload("res://assets/box.png")    ## wooden crate: brown planks, dark border, X-brace
var _tex_coin     := preload("res://assets/coin.png")
var _tex_gem      := preload("res://assets/diamond.png")
var _mov_script   := preload("res://scripts/MovingObstacle.gd")
var _tower_scene  := preload("res://scenes/WaterTower.tscn")
var _algo_pu_script := preload("res://scripts/AlgoPowerUp.gd")
var _grav_zone_script := preload("res://scripts/GravityZone.gd")

# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_diamonds_left = diamonds_per_run

func set_difficulty(rate: float, mn: float, mx: float, dpr: int, speed: float, lv: int = 1) -> void:
	spawn_rate           = rate
	min_gap              = mn
	max_gap              = mx
	diamonds_per_run     = dpr
	_diamonds_left       = dpr
	_speed_ref           = speed
	_difficulty_level    = lv
	_last_diamond_x      = 0.0
	_coin_x              = 900.0   # restart trail from level start
	_alt_black_obs       = false
	_powerup_cycle_idx   = 0
	_last_powerup_x      = 0.0
	_last_gravity_zone_x = -9999.0
	_active_zones.clear()

func _min_fair_gap() -> float:
	return maxf(min_gap, _speed_ref * (2.0 * 700.0 / 1600.0) + 80.0)

func _pick_obs_type() -> ObsType:
	var w : Array[int]
	if _difficulty_level <= 1:
		w = [22, 14, 8, 10, 6, 6, 12, 12, 10]
	elif _difficulty_level == 2:
		w = [10, 12, 10, 12, 10, 10, 12, 12, 12]
	elif _difficulty_level == 3:
		w = [8, 10, 10, 10, 10, 12, 13, 13, 14]
	else:   # Level 4+
		w = [6, 8, 9, 9, 9, 15, 14, 14, 16]
	var total : int = 0
	for v in w:
		total += v
	var r   : int = randi() % total
	var acc : int = 0
	for i in range(w.size()):
		acc += w[i]
		if r < acc:
			return ObsType.values()[i]
	return ObsType.LOW_BLOCK

func _process(_delta: float) -> void:
	if not _player:
		_player = get_node_or_null("../Player")
		if not _player:
			return
	var st = _player.get("state")
	if st == "dead" or st == null:
		return

	# 1. Spawn obstacles first (so zones are registered before coins are placed in same frame)
	if _player.global_position.x + 1800.0 > _next_x:
		if randf() < spawn_rate:
			_spawn_cluster(_next_x)
		_next_x += randf_range(_min_fair_gap(), max_gap)

	# 1b. Algorithm Power-Ups
	_maybe_spawn_algo_powerup()

	# 1c. Gravity Flip Corridors (Level 2 onward)
	if _difficulty_level >= 2:
		_maybe_spawn_gravity_zone()

	# 2. Evict zones that are far behind the player
	_clean_old_zones()

	# 3. Place trail coins (slightly shorter lookahead so obstacle zones are always registered first)
	while _player.global_position.x + 1500.0 > _coin_x:
		_place_trail_coin(_coin_x)
		_coin_x += COIN_SPACING

# ── Obstacle cluster ──────────────────────────────────────────

func _is_in_gravity_zone(x: float) -> bool:
	for child in get_children():
		if child.get_script() == _grav_zone_script:
			var w : float = child.get("zone_width") if child.get("zone_width") else 1100.0
			if x >= child.position.x - 300.0 and x <= child.position.x + w + 300.0:
				return true
	return false

func _spawn_cluster(cx: float) -> void:
	var kind     : ObsType = _pick_obs_type()
	if _is_in_gravity_zone(cx) and kind == ObsType.WATER_TOWER:
		kind = ObsType.LOW_BLOCK
	var obs_zone : Rect2   = _obstacle_zone(kind, cx)
	var top_y    : float   = _obs_top_y(kind)
	var is_beam  : bool    = (kind == ObsType.WATER_TOWER)

	add_child(_make_obstacle(kind, cx))

	# Register zone so the coin trail can arc over / dip under this obstacle
	_active_zones.append({
		"rect":    obs_zone,
		"kind":    int(kind),
		"top_y":   top_y,
		"is_beam": is_beam
	})

	# ── Diamond placement (distance-based interval) ───────────────
	var diamond_gap : float = DIAMOND_INTERVAL * COIN_SPACING   # px
	var dist_since  : float = cx - _last_diamond_x
	if _diamonds_left > 0 and dist_since >= diamond_gap:
		var gem_x : float = cx + 120.0
		var gem_y : float = GROUND_Y - 160.0
		if not _is_water_tank_coin_blocked(gem_x) and _clear_of_zone(gem_x, gem_y, obs_zone, 40.0) and _clear_of_siblings(gem_x, gem_y):
			add_child(_make_collectible(gem_x, gem_y, Collectible.Type.DIAMOND))
			_diamonds_left  -= 1
			_last_diamond_x  = cx

# ── Continuous coin trail ─────────────────────────────────────

## Returns true if cx is inside a water tank, immediately adjacent to one,
## or anywhere in the gap between two consecutive water tanks.
func _is_water_tank_coin_blocked(coin_x: float) -> bool:
	var wt_spans: Array[Vector2] = []
	for info in _active_zones:
		if info.get("kind") == int(ObsType.WATER_TOWER):
			var z : Rect2 = info["rect"]
			# Span covers the water tank footprint plus approach/exit margin
			wt_spans.append(Vector2(z.position.x - 60.0, z.position.x + z.size.x + 60.0))

	if wt_spans.is_empty():
		return false

	# 1. Skip if coin_x is inside or directly adjacent to any water tank
	for span in wt_spans:
		if coin_x >= span.x and coin_x <= span.y:
			return true

	# 2. Skip if coin_x is anywhere in the span between two water tanks
	wt_spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for i in range(wt_spans.size() - 1):
		var gap_start : float = wt_spans[i].y
		var gap_end   : float = wt_spans[i + 1].x
		if gap_end > gap_start:
			if coin_x >= gap_start and coin_x <= gap_end:
				return true

	return false

## Place one trail coin at world-x = cx, height determined by _get_trail_y.
func _place_trail_coin(cx: float) -> void:
	if _is_water_tank_coin_blocked(cx):
		return
	add_child(_make_collectible(cx, _get_trail_y(cx), Collectible.Type.COIN))

## Compute the y coordinate of the trail coin at world-x = cx.
##   • Default: TRAIL_Y (55 px above ground — collectable while running).
##   • Jump arc: smooth parabola rises over any non-beam obstacle.
##   • Slide gap: coin placed inside the gap (GROUND_Y - 30).
##   • Diamond overlap: coin shifted down to avoid visual overlap.
func _get_trail_y(cx: float) -> float:
	var cy : float = TRAIL_Y

	for info in _active_zones:
		var zone    : Rect2 = info["rect"]
		var is_beam : bool  = info["is_beam"]
		var top_y   : float = info["top_y"]

		# Horizontal extent: no approach buffer for beams (only adjust inside gap)
		var left  : float = zone.position.x - (0.0 if is_beam else ARC_PAD)
		var right : float = zone.position.x + zone.size.x + (0.0 if is_beam else ARC_PAD)

		if cx < left or cx > right:
			continue

		if is_beam:
			# Coin inside the slide gap: player collects while sliding
			cy = GROUND_Y - 30.0
			continue

		# Smooth parabolic arc: rises from TRAIL_Y to peak above obstacle, falls back
		var center    : float = (left + right) * 0.5
		var half_span : float = (right - left) * 0.5
		var dx        : float = cx - center
		var t         : float = clampf(1.0 - (dx * dx) / (half_span * half_span), 0.0, 1.0)

		# Peak: 50 px clearance above actual obstacle top, clamped to reachable range
		var peak_y : float = clampf(top_y - 50.0, GROUND_Y - 150.0, TRAIL_Y - 30.0)
		var arc_y  : float = TRAIL_Y + (peak_y - TRAIL_Y) * t
		cy = minf(cy, arc_y)   # keep the highest requested position (smallest y)

	# Diamond overlap check: shift coin DOWN away from any nearby diamond
	for child in get_children():
		if child is Collectible:
			var c := child as Collectible
			if c.kind == Collectible.Type.DIAMOND:
				var dx : float = absf(c.position.x - cx)
				if dx < 35.0:
					# Move coin at least (diamond_r + coin_r + 6) below diamond centre
					cy = minf(maxf(cy, c.position.y + 40.0), GROUND_Y - 25.0)

	return cy

## Actual top-edge y of the obstacle (world coords). Used for arc clearance.
func _obs_top_y(kind: ObsType) -> float:
	match kind:
		ObsType.LOW_BLOCK:    return GROUND_Y - 60.0
		ObsType.TALL_WALL:    return GROUND_Y - 110.0
		ObsType.SOLID_BLACK:  return GROUND_Y - (70.0 if _alt_black_obs else 40.0)
		ObsType.DOUBLE_BLOCK: return GROUND_Y - 60.0
		ObsType.MOVING_OBS:   return GROUND_Y - 60.0   # use grounded height for arc; bobs up at runtime
		ObsType.HIGH_LOW_COMBO: return GROUND_Y - 110.0  # dominated by the tall wall
		ObsType.AC_ROW:       return GROUND_Y - 40.0
		ObsType.VENT_UNIT:    return GROUND_Y - 55.0
		ObsType.WATER_TOWER:  return GROUND_Y - 320.0
	return GROUND_Y - 60.0

## Removes obstacle zones whose right edge is more than 300 px behind the player.
func _clean_old_zones() -> void:
	if not _player:
		return
	var cutoff : float = _player.global_position.x - 300.0
	var i      : int   = _active_zones.size() - 1
	while i >= 0:
		var z : Rect2 = _active_zones[i]["rect"]
		if z.position.x + z.size.x < cutoff:
			_active_zones.remove_at(i)
		i -= 1

	# Clean up offscreen powerups and gravity zones
	var far_behind : float = _player.global_position.x - 1200.0
	for child in get_children():
		if child.get_script() == _algo_pu_script and child.position.x < far_behind:
			child.queue_free()
		elif child.get_script() == _grav_zone_script and child.position.x + (child.get("zone_width") if child.get("zone_width") else 1100.0) < far_behind:
			child.queue_free()

# ── Power-Up & Gravity Zone Spawning ─────────────────────────

func _maybe_spawn_algo_powerup() -> void:
	if not _player:
		return
	var min_target : float = maxf(_player.global_position.x + 1300.0, _last_powerup_x + 2300.0)
	if _player.global_position.x + 1500.0 < min_target:
		return
	var cx : float = min_target
	var pu = _algo_pu_script.new()
	pu.power_type = _powerup_cycle_idx % 4
	pu.position = Vector2(cx, GROUND_Y - 90.0)
	pu.collected.connect(_on_powerup_collected)
	add_child(pu)
	_last_powerup_x = cx
	_powerup_cycle_idx += 1

func _on_powerup_collected(type: int) -> void:
	var pm = get_node_or_null("../PowerUpManager")
	if not pm and get_tree() and get_tree().root:
		pm = get_tree().root.find_child("PowerUpManager", true, false)
	if pm and pm.has_method("on_collected"):
		pm.on_collected(type)

func _maybe_spawn_gravity_zone() -> void:
	if not _player:
		return
	var min_x : float = maxf(_player.global_position.x + 1400.0, _last_gravity_zone_x + 3200.0)
	if _player.global_position.x + 1600.0 < min_x:
		return

	# Avoid placing gravity zone over any active water tower
	for z in _active_zones:
		if z.get("is_beam", false):
			var r : Rect2 = z["rect"]
			if r.position.x + r.size.x > min_x - 300.0 and r.position.x < min_x + 1400.0:
				_last_gravity_zone_x = r.position.x + r.size.x + 300.0
				return

	if randf() > 0.45:
		_last_gravity_zone_x = _player.global_position.x + 800.0
		return
	var gz = _grav_zone_script.new()
	gz.position = Vector2(min_x, GROUND_Y)
	gz.gravity_changed.connect(_on_gravity_changed)
	add_child(gz)
	_last_gravity_zone_x = min_x

func _on_gravity_changed(inverted: bool) -> void:
	if _player and _player.has_method("flip_gravity"):
		_player.flip_gravity(inverted)
	var cam = get_node_or_null("../Player/Camera2D")
	if not cam and get_tree() and get_tree().root:
		cam = get_tree().root.find_child("Camera2D", true, false)
	if cam and cam.has_method("set_gravity_flipped"):
		cam.set_gravity_flipped(inverted)

# ── Obstacle builders ─────────────────────────────────────────

func _make_obstacle(kind: ObsType, cx: float) -> Node2D:
	match kind:
		ObsType.LOW_BLOCK:      return _antenna_obstacle(cx)
		ObsType.TALL_WALL:      return _solid_box(cx, GROUND_Y - 55.0, 50.0, 110.0, _tex_tall)
		ObsType.SOLID_BLACK:    return _alt_black_prop(cx)
		ObsType.DOUBLE_BLOCK:   return _double_block(cx)
		ObsType.MOVING_OBS:     return _moving_obstacle(cx)
		ObsType.HIGH_LOW_COMBO: return _high_low_combo(cx)
		ObsType.AC_ROW:         return _ac_row(cx)
		ObsType.VENT_UNIT:      return _vent_unit(cx)
		ObsType.WATER_TOWER:    return _water_tower(cx)
	return _antenna_obstacle(cx)

func _antenna_obstacle(cx: float) -> Area2D:
	var area := Area2D.new()
	area.position = Vector2(cx, GROUND_Y)

	var vis := _AntennaVisual.new()
	area.add_child(vis)
	var light := _AntennaLight.new()
	area.add_child(light)

	# Deadly hazard collision shapes (shrunk by ~3 px on each side):
	# 1. Sign shape: visible is width 54, height 22 (y = -49 to -71). Shrunk: width 48, height 16.
	var col_sign := CollisionShape2D.new()
	var shp_sign := RectangleShape2D.new()
	shp_sign.size = Vector2(48.0, 16.0)
	col_sign.shape = shp_sign
	col_sign.position = Vector2(0.0, -60.0)
	area.add_child(col_sign)

	# 2. Upper mast & crossbars shape: visible width up to 26, height -71 to -86. Shrunk: width 20, height 14.
	var col_mast := CollisionShape2D.new()
	var shp_mast := RectangleShape2D.new()
	shp_mast.size = Vector2(20.0, 14.0)
	col_mast.shape = shp_mast
	col_mast.position = Vector2(0.0, -78.0)
	area.add_child(col_mast)

	area.body_entered.connect(_on_antenna_hit.bind(area))
	return area

func _on_antenna_hit(body: Node, obs: Area2D) -> void:
	if body.name != "Player" or body.get("state") == "dead":
		return
	if obs.get_meta("triggered", false):
		return
	obs.set_meta("triggered", true)

	body.set("state", "dead")
	body.set_physics_process(false)
	if "velocity" in body:
		body.velocity = Vector2.ZERO

	# Play short spark effect at contact point for 0.2 s
	var contact_pos := Vector2(body.global_position.x + 10.0, clampf(body.global_position.y, GROUND_Y - 80.0, GROUND_Y - 55.0))
	var sparks := _SparkEffect.new()
	sparks.global_position = contact_pos
	add_child(sparks)

	# 0.2 s delay before Game Over screen
	get_tree().create_timer(0.2).timeout.connect(
		func() -> void:
			if is_instance_valid(sparks):
				sparks.queue_free()
			if is_instance_valid(body):
				body.died.emit()
	)

func _solid_box(cx: float, cy: float, w: float, h: float, tex: Texture2D) -> StaticBody2D:
	var obs := StaticBody2D.new()
	obs.position = Vector2(cx, cy)
	var sp := Sprite2D.new()
	sp.texture  = tex
	var ts      := tex.get_size()
	sp.scale    = Vector2(w / ts.x, h / ts.y)
	sp.modulate = Color(0.18, 0.20, 0.35)
	obs.add_child(sp)

	var trim := _CyberBarricadeTrim.new()
	trim.size = Vector2(w, h)
	obs.add_child(trim)

	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size    = Vector2(w, h)
	col.shape   = shp
	obs.add_child(col)
	return obs

class _CyberBarricadeTrim extends Node2D:
	var size : Vector2 = Vector2.ZERO
	func _draw() -> void:
		if size.x <= 0.0: return
		var hw : float = size.x * 0.5
		var hh : float = size.y * 0.5
		draw_rect(Rect2(-hw, -hh, size.x, size.y), Color(0.00, 0.92, 0.98, 0.9), false, 2.0)
		draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), Color(0.65, 0.20, 1.00, 1.0), 3.0)
		draw_circle(Vector2(-hw + 3.0, -hh + 3.0), 2.0, Color(0.00, 0.92, 0.98))
		draw_circle(Vector2(hw - 3.0, -hh + 3.0), 2.0, Color(0.00, 0.92, 0.98))

func _on_beam_enter(body: Node, _area: Node) -> void:
	if body.name == "Player" and body.get("state") != "slide":
		body.stun()

func _alt_black_prop(cx: float) -> StaticBody2D:
	var obs : StaticBody2D = _cyl_tank(cx) if _alt_black_obs else _drum(cx)
	_alt_black_obs = not _alt_black_obs
	return obs

## Black cylindrical tank obstacle: 40 px wide × 70 px tall, solid collision.
func _cyl_tank(cx: float) -> StaticBody2D:
	var obs := StaticBody2D.new()
	obs.position = Vector2(cx, GROUND_Y - 35.0)   # center at half-height
	obs.collision_layer = 1
	obs.collision_mask = 1
	var vis := _CylTankVisual.new()
	obs.add_child(vis)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size  = Vector2(40.0, 70.0)
	col.shape = shp
	obs.add_child(col)
	return obs

## Black drum/barrel obstacle: 50 px wide × 40 px tall, solid collision.
func _drum(cx: float) -> StaticBody2D:
	var obs := StaticBody2D.new()
	obs.position = Vector2(cx, GROUND_Y - 20.0)   # center at half-height
	obs.collision_layer = 1
	obs.collision_mask = 1
	var vis := _DrumVisual.new()
	obs.add_child(vis)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size  = Vector2(50.0, 40.0)
	col.shape = shp
	obs.add_child(col)
	return obs

func _double_block(cx: float) -> Node2D:
	var root := Node2D.new()
	root.add_child(_solid_box(cx, GROUND_Y - 30.0, 60.0, 60.0, _tex_box))
	root.add_child(_solid_box(cx + 180.0, GROUND_Y - 30.0, 60.0, 60.0, _tex_box))
	return root

func _moving_obstacle(cx: float) -> Node2D:
	var obs : Node2D = _mov_script.new()
	obs.position = Vector2(cx, GROUND_Y - 30.0)
	obs.call("init", 75.0, 0.65 + randf() * 0.3)
	var sp := Sprite2D.new()
	sp.texture = _tex_box
	var ts     := _tex_box.get_size()
	sp.scale   = Vector2(80.0 / ts.x, 60.0 / ts.y)
	# No modulate — display natural wooden-crate colors
	obs.add_child(sp)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size  = Vector2(80.0, 60.0)
	col.shape = shp
	obs.add_child(col)
	return obs

func _high_low_combo(cx: float) -> Node2D:
	var root := Node2D.new()
	root.add_child(_solid_box(cx, GROUND_Y - 55.0, 50.0, 110.0, _tex_tall))
	root.add_child(_vent_unit(cx + 200.0))
	return root

## AC_Row: 3 side-by-side low units 150x40, solid collision.
func _ac_row(cx: float) -> StaticBody2D:
	var obs := StaticBody2D.new()
	obs.position = Vector2(cx, GROUND_Y - 20.0)   # center at half-height (40h)
	obs.collision_layer = 1
	obs.collision_mask = 1
	var vis := _ACRowVisual.new()
	vis.position = Vector2(0.0, 20.0)
	obs.add_child(vis)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size  = Vector2(150.0, 40.0)
	col.shape = shp
	obs.add_child(col)
	return obs

## VentUnit: 60x55 unit with one fan circle plus two capped pipe stacks.
func _vent_unit(cx: float) -> StaticBody2D:
	var obs := StaticBody2D.new()
	obs.position = Vector2(cx, GROUND_Y - 27.5)   # center at half-height (55h)
	obs.collision_layer = 1
	obs.collision_mask = 1
	var vis := _VentUnitVisual.new()
	vis.position = Vector2(0.0, 27.5)
	obs.add_child(vis)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size  = Vector2(60.0, 55.0)
	col.shape = shp
	obs.add_child(col)
	return obs

## WaterTower: tall tower total height ~320 px, tank 120x90, X-braced legs.
## Legs = NO blocking collision (player slides through 55 px gap or climbs legs).
func _water_tower(cx: float) -> Node2D:
	var root : Node2D = _tower_scene.instantiate()
	root.position = Vector2(cx, GROUND_Y)
	if root.has_signal("collectible_picked"):
		root.collectible_picked.connect(func(k: int) -> void: collectible_picked.emit(k))
	return root


# ── Zone / clearance helpers ──────────────────────────────────

## Returns a Rect2 covering the obstacle collision zone + obs_clearance margin.
func _obstacle_zone(kind: ObsType, cx: float) -> Rect2:
	match kind:
		ObsType.LOW_BLOCK:
			return Rect2(cx - 45.0 - obs_clearance, GROUND_Y - 60.0 - obs_clearance,
						 90.0 + obs_clearance * 2.0, 60.0 + obs_clearance)
		ObsType.TALL_WALL:
			return Rect2(cx - 25.0 - obs_clearance, GROUND_Y - 110.0 - obs_clearance,
						 50.0 + obs_clearance * 2.0, 110.0 + obs_clearance)
		ObsType.SOLID_BLACK:
			if _alt_black_obs:
				# WaterTank: 40 px wide, 70 px tall, centered at cx
				return Rect2(cx - 20.0 - obs_clearance, GROUND_Y - 70.0 - obs_clearance,
							 40.0 + obs_clearance * 2.0, 70.0 + obs_clearance)
			else:
				# BlackDrum: 50 px wide, 40 px tall, centered at cx
				return Rect2(cx - 25.0 - obs_clearance, GROUND_Y - 40.0 - obs_clearance,
							 50.0 + obs_clearance * 2.0, 40.0 + obs_clearance)
		ObsType.DOUBLE_BLOCK:
			return Rect2(cx - 30.0 - obs_clearance, GROUND_Y - 60.0 - obs_clearance,
						 240.0 + obs_clearance * 2.0, 60.0 + obs_clearance)
		ObsType.MOVING_OBS:
			return Rect2(cx - 40.0 - obs_clearance, GROUND_Y - 135.0 - obs_clearance,
						 80.0 + obs_clearance * 2.0, 135.0 + obs_clearance)
		ObsType.HIGH_LOW_COMBO:
			return Rect2(cx - 25.0 - obs_clearance, GROUND_Y - 110.0 - obs_clearance,
						 260.0 + obs_clearance * 2.0, 110.0 + obs_clearance)
		ObsType.AC_ROW:
			return Rect2(cx - 75.0 - obs_clearance, GROUND_Y - 40.0 - obs_clearance,
						 150.0 + obs_clearance * 2.0, 40.0 + obs_clearance)
		ObsType.VENT_UNIT:
			return Rect2(cx - 30.0 - obs_clearance, GROUND_Y - 55.0 - obs_clearance,
						 60.0 + obs_clearance * 2.0, 55.0 + obs_clearance)
		ObsType.WATER_TOWER:
			return Rect2(cx - 65.0 - obs_clearance, GROUND_Y - 320.0 - obs_clearance,
						 130.0 + obs_clearance * 2.0, 320.0 + obs_clearance)
	return Rect2(cx - obs_clearance, GROUND_Y - obs_clearance, obs_clearance * 2.0, obs_clearance)


## True when point (px, py) lies outside zone grown by extra px.
func _clear_of_zone(px: float, py: float, zone: Rect2, extra: float = 0.0) -> bool:
	return not zone.grow(extra).has_point(Vector2(px, py))

## True when (px, py) is far enough from every already-placed diamond.
## Used exclusively for diamond–diamond and diamond–existing-diamond separation.
func _clear_of_siblings(px: float, py: float) -> bool:
	var min_dist : float = COIN_SPACING * 0.85
	for child in get_children():
		if child is Collectible:
			if Vector2(px, py).distance_to(child.position) < min_dist:
				return false
	return true

func _make_collectible(x: float, y: float, kind: Collectible.Type) -> Collectible:
	var c := Collectible.new()
	c.kind     = kind
	c.position = Vector2(x, y)
	c.picked_up.connect(func(k: int) -> void: collectible_picked.emit(k))
	var col := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 14.0 if kind == Collectible.Type.COIN else 20.0
	col.shape  = shp
	c.add_child(col)
	return c

## Tiny helper that draws a dark ring behind coin sprites for bright-background visibility.
class _CoinOutline extends Node2D:
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.1, 0.1, 0.1, 0.6), 2.0, true)

## Procedural visual for the freestanding deadly antenna obstacle (replaces old low dark-red block).
class _AntennaVisual extends Node2D:
	const HAZARD_YELLOW : Color = Color(0.00, 0.92, 0.98)
	const HAZARD_BLACK  : Color = Color(0.02, 0.02, 0.06)
	const PANEL_RED     : Color = Color(0.85, 0.10, 0.45)
	const MAST_GRAY     : Color = Color(0.20, 0.22, 0.32)
	const MAST_DARK     : Color = Color(0.08, 0.09, 0.16)
	const OUTLINE       : Color = Color(0.01, 0.01, 0.04)
	const WARN_YELLOW   : Color = Color(0.00, 0.95, 1.00)

	func _draw() -> void:
		# -- 1. Ground base plate at GROUND_Y (y = 0.0) ---------------
		# Outer black outline
		draw_rect(Rect2(-16.0, -4.5, 32.0, 4.5), OUTLINE)
		# Dark metallic plate
		draw_rect(Rect2(-15.0, -3.5, 30.0, 3.5), MAST_DARK)
		# Bolt rivets on plate
		draw_circle(Vector2(-10.0, -2.0), 1.2, OUTLINE)
		draw_circle(Vector2(10.0, -2.0), 1.2, OUTLINE)

		# Triangular mast mounting gussets / base brackets
		var gusset_l := PackedVector2Array([Vector2(-8.0, -3.5), Vector2(-2.0, -3.5), Vector2(-2.0, -12.0)])
		var gusset_r := PackedVector2Array([Vector2(8.0, -3.5), Vector2(2.0, -3.5), Vector2(2.0, -12.0)])
		draw_polyline(gusset_l, OUTLINE, 2.0)
		draw_colored_polygon(gusset_l, MAST_GRAY)
		draw_polyline(gusset_r, OUTLINE, 2.0)
		draw_colored_polygon(gusset_r, MAST_GRAY)

		# -- 2. Vertical antenna mast pole (y = -3.5 to -85.5) --------
		# Outline
		draw_rect(Rect2(-3.5, -85.5, 7.0, 82.0), OUTLINE)
		# Mast body
		draw_rect(Rect2(-2.0, -84.5, 4.0, 81.0), MAST_GRAY)
		# Center highlight line
		draw_line(Vector2(0.0, -84.0), Vector2(0.0, -4.0), Color(0.48, 0.49, 0.52), 1.0)

		# -- 3. Horizontal crossbars & dishes --------------------------
		# Middle crossbar at y = -74.0 (width 26 px)
		draw_rect(Rect2(-14.0, -75.5, 28.0, 3.5), OUTLINE)
		draw_rect(Rect2(-13.0, -75.0, 26.0, 2.5), MAST_GRAY)
		# Crossbar end caps
		draw_rect(Rect2(-15.5, -77.0, 2.5, 6.0), OUTLINE)
		draw_rect(Rect2(13.0, -77.0, 2.5, 6.0), OUTLINE)

		# Upper crossbar at y = -81.0 (width 18 px)
		draw_rect(Rect2(-10.0, -82.0, 20.0, 3.0), OUTLINE)
		draw_rect(Rect2(-9.0, -81.5, 18.0, 2.0), MAST_GRAY)

		# Top dish / cap at y = -85.5 (width 10 px)
		draw_rect(Rect2(-6.0, -86.5, 12.0, 2.5), OUTLINE)
		draw_rect(Rect2(-5.0, -86.0, 10.0, 1.5), MAST_DARK)

		# -- 4. "DANGER" Sign hung on mast (centered at y = -60.0) -----
		# Outer black border (56 x 24)
		draw_rect(Rect2(-28.0, -72.0, 56.0, 24.0), OUTLINE)

		# Yellow-and-black hazard striped border panel (54 x 22)
		draw_rect(Rect2(-27.0, -71.0, 54.0, 22.0), HAZARD_YELLOW)
		var stripe_w : float = 5.0
		var stripe_step : float = 10.0
		var sign_h : float = 22.0
		for i in range(-5, 8):
			var x_top : float = -27.0 + float(i) * stripe_step
			var p : PackedVector2Array = PackedVector2Array([
				Vector2(x_top, -71.0),
				Vector2(x_top + stripe_w, -71.0),
				Vector2(x_top + stripe_w - sign_h, -49.0),
				Vector2(x_top - sign_h, -49.0)
			])
			var clipped := _clip_poly(p, -27.0, 27.0, -71.0, -49.0)
			if clipped.size() >= 3:
				draw_colored_polygon(clipped, HAZARD_BLACK)

		# Inner red-black panel (46 x 16, centered at y = -60.0)
		draw_rect(Rect2(-24.0, -68.0, 48.0, 16.0), OUTLINE)
		draw_rect(Rect2(-23.0, -67.0, 46.0, 14.0), PANEL_RED)

		# Inner panel bevel highlight
		draw_line(Vector2(-22.0, -66.0), Vector2(22.0, -66.0), Color(0.78, 0.18, 0.20), 1.0)
		draw_line(Vector2(-22.0, -54.0), Vector2(22.0, -54.0), Color(0.30, 0.03, 0.04), 1.0)

		# Sign mounting brackets / rivets to mast
		draw_circle(Vector2(0.0, -69.0), 1.5, OUTLINE)
		draw_circle(Vector2(0.0, -51.0), 1.5, OUTLINE)

		# "DANGER" in bold white capital letters with black outline
		var font : Font = ThemeDB.fallback_font
		var text : String = "DANGER"
		var text_pos := Vector2(-22.0, -56.5)
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, 2, OUTLINE)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, Color.WHITE)
		draw_string(font, text_pos + Vector2(0.5, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, Color.WHITE)

	func _clip_poly(pts: PackedVector2Array, min_x: float, max_x: float, min_y: float, max_y: float) -> PackedVector2Array:
		var p_x := _clip_poly_axis(pts, true, min_x, true)
		p_x = _clip_poly_axis(p_x, true, max_x, false)
		var p_y := _clip_poly_axis(p_x, false, min_y, true)
		return _clip_poly_axis(p_y, false, max_y, false)

	func _clip_poly_axis(pts: PackedVector2Array, is_x: bool, bound: float, is_min: bool) -> PackedVector2Array:
		var out : PackedVector2Array = PackedVector2Array()
		var n : int = pts.size()
		if n < 3:
			return out
		for i in range(n):
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var val_a : float = a.x if is_x else a.y
			var val_b : float = b.x if is_x else b.y
			var inside_a : bool = (val_a >= bound) if is_min else (val_a <= bound)
			var inside_b : bool = (val_b >= bound) if is_min else (val_b <= bound)
			if inside_a:
				if inside_b:
					out.append(b)
				else:
					var t : float = (bound - val_a) / (val_b - val_a)
					out.append(a.lerp(b, t))
			else:
				if inside_b:
					var t : float = (bound - val_a) / (val_b - val_a)
					out.append(a.lerp(b, t))
					out.append(b)
		return out

## Pulsing red warning light on the antenna mast tip.
class _AntennaLight extends Node2D:
	func _ready() -> void:
		var tw := create_tween().set_loops()
		tw.tween_property(self, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "modulate:a", 1.00, 0.55).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var tip_pos := Vector2(0.0, -86.5)
		draw_circle(tip_pos, 7.0, Color(1.00, 0.15, 0.15, 0.35))
		draw_circle(tip_pos, 4.5, Color(1.00, 0.25, 0.25, 0.70))
		draw_circle(tip_pos, 2.5, Color(1.00, 0.92, 0.92, 1.00))
		draw_arc(tip_pos, 2.7, 0.0, TAU, 16, Color(0.05, 0.05, 0.05, 0.90), 0.8, true)

## Short spark effect played at contact point on death.
class _SparkEffect extends Node2D:
	var _time: float = 0.0
	var _angles: Array[float] = [0.2, 0.9, 1.7, 2.5, 3.4, 4.1, 4.9, 5.7]
	var _lengths: Array[float] = [18.0, 24.0, 15.0, 22.0, 17.0, 25.0, 19.0, 21.0]

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var prog: float = clampf(_time / 0.2, 0.0, 1.0)
		var alpha: float = 1.0 - prog
		# Central flash core
		var core_r: float = maxf(6.0 * (1.0 - prog), 0.5)
		draw_circle(Vector2.ZERO, core_r, Color(1.0, 1.0, 1.0, alpha))
		draw_circle(Vector2.ZERO, core_r * 0.6, Color(1.0, 0.95, 0.4, alpha))

		# Radiating electric spark lines
		for i in range(_angles.size()):
			var ang: float = _angles[i]
			var max_len: float = _lengths[i]
			var start_dist: float = max_len * prog * 0.4
			var end_dist: float = max_len * (0.3 + 0.7 * prog)
			var dir := Vector2(cos(ang), sin(ang))
			var p1 := dir * start_dist
			var p2 := dir * end_dist
			var col := Color(1.0, 0.95, 0.3, alpha) if (i % 2 == 0) else Color(1.0, 1.0, 1.0, alpha)
			draw_line(p1, p2, col, 1.8)

## Black cylindrical tank visual: 40 px wide × 70 px tall, drawn centered at (0, 0).
## StaticBody2D origin is at y = GROUND_Y - 35 (half-height), so local y = 0 is the center.
class _CylTankVisual extends Node2D:
	const C_BODY    : Color = Color(0.04, 0.04, 0.09)
	const C_OUTLINE : Color = Color(0.0, 0.0, 0.0)
	const C_BAND    : Color = Color(0.00, 0.95, 1.00)    ## neon cyan plasma ring
	const C_BAND2   : Color = Color(0.65, 0.15, 1.00)    ## neon purple energy ring
	const C_RIVET   : Color = Color(0.00, 0.92, 0.98)    ## cyan power dots
	const W         : float = 40.0
	const H         : float = 70.0

	func _draw() -> void:
		# Body rectangle (centered at origin)
		draw_rect(Rect2(-W * 0.5, -H * 0.5, W, H), C_OUTLINE)
		draw_rect(Rect2(-W * 0.5 + 1.0, -H * 0.5 + 1.0, W - 2.0, H - 2.0), C_BODY)

		# Light top band (8 px tall)
		draw_rect(Rect2(-W * 0.5 + 1.0, -H * 0.5 + 1.0, W - 2.0, 8.0), C_BAND)
		# Divider line under top band
		draw_line(Vector2(-W * 0.5 + 1.0, -H * 0.5 + 9.0),
				  Vector2( W * 0.5 - 1.0, -H * 0.5 + 9.0), C_OUTLINE, 1.0)

		# Secondary band (4 px) a bit lower
		draw_rect(Rect2(-W * 0.5 + 1.0, -H * 0.5 + 1.0 + 8.0, W - 2.0, 4.0), C_BAND2)

		# Vertical seam line (centre)
		draw_line(Vector2(0.0, -H * 0.5 + 13.0), Vector2(0.0, H * 0.5 - 1.0),
				  C_RIVET, 1.0)

		# Rivets (3 rows, 2 per side)
		for row in [0.30, 0.55, 0.80]:
			var ry : float = -H * 0.5 + row * H
			draw_circle(Vector2(-W * 0.5 + 4.0, ry), 1.5, C_RIVET)
			draw_circle(Vector2( W * 0.5 - 4.0, ry), 1.5, C_RIVET)

		# Highlight sheen (left edge)
		draw_line(Vector2(-W * 0.5 + 2.0, -H * 0.5 + 14.0),
				  Vector2(-W * 0.5 + 2.0,  H * 0.5 - 2.0),
				  Color(1.0, 1.0, 1.0, 0.08), 2.0)

## Black barrel/drum visual: 50 px wide × 40 px tall, drawn centered at (0, 0).
## StaticBody2D origin is at y = GROUND_Y - 20 (half-height).
class _DrumVisual extends Node2D:
	const C_BODY    : Color = Color(0.04, 0.04, 0.09)
	const C_OUTLINE : Color = Color(0.0, 0.0, 0.0)
	const C_RING    : Color = Color(0.00, 0.92, 0.98)    ## neon cyan hoops
	const C_RING_HI : Color = Color(0.70, 0.20, 1.00)    ## neon purple trim
	const W         : float = 50.0
	const H         : float = 40.0

	func _draw() -> void:
		# Body
		draw_rect(Rect2(-W * 0.5, -H * 0.5, W, H), C_OUTLINE)
		draw_rect(Rect2(-W * 0.5 + 1.0, -H * 0.5 + 1.0, W - 2.0, H - 2.0), C_BODY)

		# Top cap (ellipse-like rect, slightly wider)
		draw_rect(Rect2(-W * 0.5 - 1.0, -H * 0.5, W + 2.0, 5.0), C_RING)
		draw_line(Vector2(-W * 0.5 - 1.0, -H * 0.5 + 2.0),
				  Vector2( W * 0.5 + 1.0, -H * 0.5 + 2.0), C_RING_HI, 1.0)

		# Bottom cap
		draw_rect(Rect2(-W * 0.5 - 1.0, H * 0.5 - 5.0, W + 2.0, 5.0), C_RING)

		# Three grey horizontal bands / hoops
		for frac in [0.25, 0.50, 0.75]:
			var ry : float = -H * 0.5 + frac * H
			draw_rect(Rect2(-W * 0.5, ry - 1.5, W, 4.0), C_RING)
			draw_line(Vector2(-W * 0.5, ry - 0.5), Vector2(W * 0.5, ry - 0.5),
					  C_RING_HI, 1.0)

		# Highlight sheen
		draw_line(Vector2(-W * 0.5 + 2.5, -H * 0.5 + 5.0),
				  Vector2(-W * 0.5 + 2.5,  H * 0.5 - 5.0),
				  Color(1.0, 1.0, 1.0, 0.08), 2.0)

## Procedural visual for AC_Row: 3 side-by-side low units 150x40 (black silhouette).
class _ACRowVisual extends Node2D:
	const C_BLACK : Color = Color(0.04, 0.04, 0.05)
	const C_DARK  : Color = Color(0.14, 0.14, 0.16)

	func _draw() -> void:
		# Base rail & 4 support feet (sitting on ground at y = 0.0)
		draw_rect(Rect2(-73.0, -3.5, 146.0, 3.5), C_BLACK)
		for fx in [-68.0, -23.0, 23.0, 68.0]:
			draw_rect(Rect2(fx - 3.5, -3.0, 7.0, 3.0), C_BLACK)

		# Unit 1 (Left): 47x36 px from x = -72 to -25, y = -39.5 to -3.5
		_draw_ac_unit(-72.0, -25.0, -39.5, -3.5, -38.0, true, false)
		draw_rect(Rect2(-69.0, -41.5, 6.0, 2.0), C_BLACK)
		draw_rect(Rect2(-32.0, -41.5, 6.0, 2.0), C_BLACK)

		# Unit 2 (Middle): 46x36 px from x = -23 to 23, y = -39.5 to -3.5
		_draw_ac_unit(-23.0, 23.0, -39.5, -3.5, 0.0, false, false)
		draw_rect(Rect2(-20.0, -41.5, 6.0, 2.0), C_BLACK)
		draw_rect(Rect2(14.0, -41.5, 6.0, 2.0), C_BLACK)

		# Unit 3 (Right): 47x36 px from x = 25 to 72, y = -39.5 to -3.5
		_draw_ac_unit(25.0, 72.0, -39.5, -3.5, 54.0, false, true)
		draw_rect(Rect2(28.0, -41.5, 6.0, 2.0), C_BLACK)
		draw_rect(Rect2(65.0, -41.5, 6.0, 2.0), C_BLACK)
		# External conduit pipe on far right
		var conduit := PackedVector2Array([
			Vector2(70.0, -36.0),
			Vector2(73.5, -33.0),
			Vector2(73.5, -6.0),
			Vector2(71.0, -3.5)
		])
		draw_polyline(conduit, C_BLACK, 2.0)

	func _draw_ac_unit(x0: float, x1: float, y0: float, y1: float, fan_cx: float, has_left_vents: bool, has_right_louvers: bool) -> void:
		var fan_cy : float = (y0 + y1) * 0.5
		var r      : float = 12.0

		# Panels surrounding the fan circular opening (so sky shows through opening)
		draw_rect(Rect2(x0, y0, fan_cx - r - x0, y1 - y0), C_BLACK)
		draw_rect(Rect2(fan_cx + r, y0, x1 - (fan_cx + r), y1 - y0), C_BLACK)
		draw_rect(Rect2(fan_cx - r, y0, r * 2.0, (fan_cy - r) - y0), C_BLACK)
		draw_rect(Rect2(fan_cx - r, fan_cy + r, r * 2.0, y1 - (fan_cy + r)), C_BLACK)

		# Corner fills around circle
		var d : float = r * 0.7071
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx - r, fan_cy - r), Vector2(fan_cx - d, fan_cy - r), Vector2(fan_cx - r, fan_cy - d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx + r, fan_cy - r), Vector2(fan_cx + d, fan_cy - r), Vector2(fan_cx + r, fan_cy - d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx - r, fan_cy + r), Vector2(fan_cx - d, fan_cy + r), Vector2(fan_cx - r, fan_cy + d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx + r, fan_cy + r), Vector2(fan_cx + d, fan_cy + r), Vector2(fan_cx + r, fan_cy + d)]), C_BLACK)

		# Fan opening rim
		draw_arc(Vector2(fan_cx, fan_cy), r, 0.0, TAU, 24, C_BLACK, 1.5, true)

		# Center hub & fan blades
		var center := Vector2(fan_cx, fan_cy)
		draw_circle(center, 3.0, C_BLACK)
		for ang in [0.35, 1.92, 3.49, 5.06]:
			var dir := Vector2(cos(ang), sin(ang))
			var norm := Vector2(-dir.y, dir.x) * 2.2
			var blade := PackedVector2Array([
				center + dir * 2.5,
				center + dir * (r - 0.5) + norm,
				center + dir * (r - 0.5) - norm
			])
			draw_colored_polygon(blade, C_BLACK)

		if has_left_vents:
			for vy in [-33.0, -28.0, -23.0, -18.0, -13.0]:
				draw_line(Vector2(x0 + 4.0, vy), Vector2(x0 + 13.0, vy), C_DARK, 1.2)
		if has_right_louvers:
			for vy in [-33.0, -27.0, -21.0, -15.0, -9.0]:
				draw_line(Vector2(x0 + 6.0, vy), Vector2(x0 + 19.0, vy), C_DARK, 1.5)

## Procedural visual for VentUnit: 60x55 unit with one fan circle + 2 capped pipe stacks.
class _VentUnitVisual extends Node2D:
	const C_BLACK : Color = Color(0.04, 0.04, 0.05)
	const C_DARK  : Color = Color(0.14, 0.14, 0.16)

	func _draw() -> void:
		# 1. Left pipe stack (x = -24 to -16, width 8)
		draw_rect(Rect2(-24.0, -46.0, 8.0, 46.0), C_BLACK)
		draw_rect(Rect2(-25.5, -40.0, 11.0, 2.5), C_BLACK)
		draw_rect(Rect2(-25.0, -4.0, 10.0, 4.0), C_BLACK)
		draw_rect(Rect2(-27.0, -52.0, 14.0, 3.5), C_BLACK)
		draw_rect(Rect2(-25.5, -53.5, 11.0, 1.5), C_BLACK)
		draw_rect(Rect2(-24.0, -48.5, 2.0, 2.5), C_BLACK)
		draw_rect(Rect2(-18.0, -48.5, 2.0, 2.5), C_BLACK)

		# 2. Right pipe stack (x = 16 to 24, width 8)
		draw_rect(Rect2(16.0, -46.0, 8.0, 46.0), C_BLACK)
		draw_rect(Rect2(14.5, -40.0, 11.0, 2.5), C_BLACK)
		draw_rect(Rect2(15.0, -4.0, 10.0, 4.0), C_BLACK)
		draw_rect(Rect2(13.0, -52.0, 14.0, 3.5), C_BLACK)
		draw_rect(Rect2(14.5, -53.5, 11.0, 1.5), C_BLACK)
		draw_rect(Rect2(16.0, -48.5, 2.0, 2.5), C_BLACK)
		draw_rect(Rect2(22.0, -48.5, 2.0, 2.5), C_BLACK)

		# 3. Center cabinet unit (x = -13 to 13, y = -47 to -3)
		var x0 : float = -13.0
		var x1 : float = 13.0
		var y0 : float = -47.0
		var y1 : float = -3.0
		var fan_cx : float = 2.0
		var fan_cy : float = -25.0
		var r : float = 10.0

		draw_rect(Rect2(-14.0, -3.0, 28.0, 3.0), C_BLACK)
		draw_rect(Rect2(-5.0, -49.5, 7.0, 2.5), C_BLACK)

		draw_rect(Rect2(x0, y0, fan_cx - r - x0, y1 - y0), C_BLACK)
		draw_rect(Rect2(fan_cx + r, y0, x1 - (fan_cx + r), y1 - y0), C_BLACK)
		draw_rect(Rect2(fan_cx - r, y0, r * 2.0, (fan_cy - r) - y0), C_BLACK)
		draw_rect(Rect2(fan_cx - r, fan_cy + r, r * 2.0, y1 - (fan_cy + r)), C_BLACK)

		var d : float = r * 0.7071
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx - r, fan_cy - r), Vector2(fan_cx - d, fan_cy - r), Vector2(fan_cx - r, fan_cy - d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx + r, fan_cy - r), Vector2(fan_cx + d, fan_cy - r), Vector2(fan_cx + r, fan_cy - d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx - r, fan_cy + r), Vector2(fan_cx - d, fan_cy + r), Vector2(fan_cx - r, fan_cy + d)]), C_BLACK)
		draw_colored_polygon(PackedVector2Array([Vector2(fan_cx + r, fan_cy + r), Vector2(fan_cx + d, fan_cy + r), Vector2(fan_cx + r, fan_cy + d)]), C_BLACK)

		draw_arc(Vector2(fan_cx, fan_cy), r, 0.0, TAU, 24, C_BLACK, 1.5, true)
		var center := Vector2(fan_cx, fan_cy)
		draw_circle(center, 2.5, C_BLACK)
		for ang in [0.4, 1.97, 3.54, 5.11]:
			var dir := Vector2(cos(ang), sin(ang))
			var norm := Vector2(-dir.y, dir.x) * 1.8
			var blade := PackedVector2Array([
				center + dir * 2.0,
				center + dir * (r - 0.5) + norm,
				center + dir * (r - 0.5) - norm
			])
			draw_colored_polygon(blade, C_BLACK)

		draw_line(Vector2(-10.0, -42.0), Vector2(-10.0, -10.0), C_DARK, 1.5)

## Procedural visual for WaterTower: tall tower (~320 px), tank 120x90, X-braced legs.
## Slide gap under the lowest cross-beam is ~55 px high.
class _WaterTowerVisual extends Node2D:
	const C_BLACK : Color = Color(0.04, 0.04, 0.05)

	func _draw() -> void:
		# ── 1. Tank on top (y = -320 to -230) ─────────────────────────
		draw_rect(Rect2(-64.0, -320.0, 128.0, 8.0), C_BLACK)
		draw_rect(Rect2(-56.0, -323.0, 112.0, 3.0), C_BLACK)
		draw_rect(Rect2(-60.0, -312.0, 120.0, 82.0), C_BLACK)
		draw_rect(Rect2(-66.0, -230.0, 132.0, 8.0), C_BLACK)

		# ── 2. Lattice Tower Legs (y = -222 to 0.0) ───────────────────
		var leg_l := PackedVector2Array([
			Vector2(-55.0, -222.0),
			Vector2(-45.0, -222.0),
			Vector2(-53.0, 0.0),
			Vector2(-63.0, 0.0)
		])
		draw_colored_polygon(leg_l, C_BLACK)

		var leg_r := PackedVector2Array([
			Vector2(45.0, -222.0),
			Vector2(55.0, -222.0),
			Vector2(63.0, 0.0),
			Vector2(53.0, 0.0)
		])
		draw_colored_polygon(leg_r, C_BLACK)

		draw_rect(Rect2(-67.0, -4.5, 18.0, 4.5), C_BLACK)
		draw_rect(Rect2(49.0, -4.5, 18.0, 4.5), C_BLACK)

		# ── 3. Cross-Beams & X-Bracing ────────────────────────────────
		# Tier 1 Horizontal Beam (y = -142 to -134, thickness 8)
		draw_rect(Rect2(-53.0, -142.0, 106.0, 8.0), C_BLACK)

		# Tier 2 Horizontal Beam (y = -62 to -54, thickness 8)
		# Below this beam (y = -54 to 0) is the open 54-55 px slide gap
		draw_rect(Rect2(-57.0, -62.0, 114.0, 8.0), C_BLACK)

		# Tier 1 X-Brace (between y = -222 and y = -142)
		_draw_brace(Vector2(-48.0, -220.0), Vector2(48.0, -144.0), 7.0)
		_draw_brace(Vector2(48.0, -220.0), Vector2(-48.0, -144.0), 7.0)

		# Tier 2 X-Brace (between y = -134 and y = -62)
		_draw_brace(Vector2(-50.0, -132.0), Vector2(52.0, -64.0), 7.0)
		_draw_brace(Vector2(50.0, -132.0), Vector2(-52.0, -64.0), 7.0)

	func _draw_brace(p1: Vector2, p2: Vector2, thickness: float) -> void:
		var dir   := (p2 - p1).normalized()
		var norm  := Vector2(-dir.y, dir.x) * (thickness * 0.5)
		var poly  := PackedVector2Array([
			p1 + norm,
			p2 + norm,
			p2 - norm,
			p1 - norm
		])
		draw_colored_polygon(poly, C_BLACK)
