## PowerUpManager.gd
## Receives collected() signals from AlgoPowerUp nodes,
## applies each algorithm-named effect, manages timers, and drives the HUD bar.
##
## 4 Power-Up Types:
## 0: Cyan   - OBSTACLE INVISIBLE: Obstacles become invisible and non-colliding (4.0s)
## 1: Purple - MATRIX SURGE: World Slowdown / Bullet-Time (2.0s countdown)
## 2: Green  - CHASER BANISH: Banishes chaser off-screen for 4.0s
## 3: Orange - COIN MAGNET: Magnetically attracts nearby coins & diamonds (2.5s)
extends Node
class_name PowerUpManager

const AlgoPowerUpScript = preload("res://scripts/AlgoPowerUp.gd")

# ── References (set by LevelManager after scene is ready) ─────
var player          : CharacterBody2D = null
var camera          : Camera2D        = null
var spawner         : Node2D          = null
var chaser          : Node2D          = null

# ── Active effect state ────────────────────────────────────────
var _active_type    : int   = -1           ## AlgoPowerUp.PowerType or -1 = none
var _active_timer   : float = 0.0          ## seconds remaining
var _active_name    : String = ""
var _active_color   : Color  = Color.WHITE

## Queue of pending power-up types
var _queue : Array[int] = []

# ── HUD nodes (built in _ready) ───────────────────────────────
var _hud_bar        : Control = null       ## parent CanvasLayer child
var _hud_label      : Label   = null
var _hud_fill       : ColorRect = null
var _hud_timer_lbl  : Label   = null
var _hud_queue_lbl  : Label   = null

# ── Cohen-Sutherland Invisible state ──────────────────────────
var _cs_active      : bool  = false

# ── Matrix Surge state ─────────────────────────────────────────
var _surge_active   : bool  = false

# ── Coin Magnet state ──────────────────────────────────────────
var _magnet_active  : bool  = false
const MAGNET_DUR    : float = 2.5
const MAGNET_RADIUS : float = 850.0
const MAGNET_SPEED  : float = 1150.0

const DURATIONS : Array[float] = [
	4.0,   ## 0: Cyan   - Obstacles invisible / phased for 4.0 seconds
	2.0,   ## 1: Purple - Matrix Surge bullet time for 2.0 seconds countdown
	4.0,   ## 2: Green  - Chaser Banish for 4.0 seconds
	2.5,   ## 3: Orange - Coin Magnet for 2.5 seconds
]

const TYPE_NAMES : Array[String] = [
	"OBSTACLES INVISIBLE", "MATRIX SURGE", "CHASER BANISH", "COIN MAGNET"
]
const TYPE_COLORS : Array[Color] = [
	Color(0.00, 0.92, 1.00),   # 0: cyan
	Color(0.68, 0.10, 1.00),   # 1: purple
	Color(0.10, 0.95, 0.30),   # 2: green
	Color(1.00, 0.47, 0.00),   # 3: orange
]

# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_hud()

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name  = "PowerUpHUD"
	canvas.layer = 20
	add_child(canvas)

	# Outer container
	_hud_bar = Control.new()
	_hud_bar.name = "PowerUpBar"
	_hud_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_bar.custom_minimum_size = Vector2(320, 54)
	_hud_bar.position = Vector2(20, 20)
	_hud_bar.visible  = false
	canvas.add_child(_hud_bar)

	# Dark background panel
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.10, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_bar.add_child(bg)

	# Color fill (progress bar)
	_hud_fill = ColorRect.new()
	_hud_fill.name    = "Fill"
	_hud_fill.color   = Color(0.00, 0.92, 1.00, 0.28)
	_hud_fill.position = Vector2.ZERO
	_hud_fill.size     = Vector2(320, 54)
	_hud_bar.add_child(_hud_fill)

	# Name label
	_hud_label = Label.new()
	_hud_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_label.offset_left = 12; _hud_label.offset_top = 4
	_hud_label.add_theme_font_size_override("font_size", 13)
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.text = ""
	_hud_bar.add_child(_hud_label)

	# Timer label
	_hud_timer_lbl = Label.new()
	_hud_timer_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_timer_lbl.offset_left = 12; _hud_timer_lbl.offset_top = 26
	_hud_timer_lbl.add_theme_font_size_override("font_size", 11)
	_hud_timer_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_hud_timer_lbl.text = ""
	_hud_bar.add_child(_hud_timer_lbl)

	# Queue label
	_hud_queue_lbl = Label.new()
	_hud_queue_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_queue_lbl.offset_left = 12; _hud_queue_lbl.offset_top = 40
	_hud_queue_lbl.add_theme_font_size_override("font_size", 10)
	_hud_queue_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_hud_queue_lbl.text = ""
	_hud_bar.add_child(_hud_queue_lbl)

## Called by Spawner when a power-up collectible is picked up.
func on_collected(type: int) -> void:
	var clean_type : int = type % 4
	if _active_type == -1 and _active_timer <= 0.0:
		_start_effect(clean_type)
	else:
		_queue.append(clean_type)
		_update_hud_queue()

func _start_effect(type: int) -> void:
	_active_type  = type
	_active_timer = DURATIONS[type]
	_active_name  = TYPE_NAMES[type]
	_active_color = TYPE_COLORS[type]
	_update_hud(1.0)
	_hud_bar.visible = true

	match type:
		AlgoPowerUpScript.PowerType.COHEN_SUTHERLAND:
			_apply_cohen_sutherland()
		AlgoPowerUpScript.PowerType.MATRIX_SURGE:
			_apply_matrix_surge()
		AlgoPowerUpScript.PowerType.CHASER_BANISH:
			_apply_chaser_banish()
		AlgoPowerUpScript.PowerType.COIN_MAGNET:
			_apply_coin_magnet()

func _process(delta: float) -> void:
	# Cyan: Keep obstacles invisible & non-colliding while active
	if _cs_active:
		_set_obstacles_invisible(true)

	# Coin Magnet pull: attract all nearby coins and diamonds to player
	if _magnet_active and player and is_instance_valid(player) and spawner:
		var p_pos : Vector2 = player.global_position + Vector2(0.0, 10.0)
		for child in spawner.get_children():
			if not is_instance_valid(child):
				continue
			if child.has_signal("picked_up"):
				var c_pos : Vector2 = child.global_position
				var dist  : float   = c_pos.distance_to(p_pos)
				if dist <= MAGNET_RADIUS:
					var dir : Vector2 = (p_pos - c_pos).normalized()
					child.global_position += dir * MAGNET_SPEED * delta

	# Active timer countdown
	if _active_timer > 0.0:
		_active_timer -= delta
		var dur : float = DURATIONS[_active_type] if _active_type >= 0 else 1.0
		var frac : float = clampf(_active_timer / dur, 0.0, 1.0)
		_update_hud(frac)
		if _active_timer <= 0.0:
			_end_effect(_active_type)

func _end_effect(type: int) -> void:
	match type:
		AlgoPowerUpScript.PowerType.COHEN_SUTHERLAND:
			_end_cohen_sutherland()
		AlgoPowerUpScript.PowerType.MATRIX_SURGE:
			Engine.time_scale = 1.0
			_surge_active = false
		AlgoPowerUpScript.PowerType.COIN_MAGNET:
			_magnet_active = false

	_active_type  = -1
	_active_timer = 0.0
	_hud_bar.visible = false

	# Dequeue next
	if _queue.size() > 0:
		var next : int = _queue[0]
		_queue.remove_at(0)
		_start_effect(next)

# ── Effect Implementations ─────────────────────────────────────

## 0: Cyan: Obstacles become invisible and non-colliding for 4 seconds.
func _apply_cohen_sutherland() -> void:
	_cs_active = true
	_set_obstacles_invisible(true)

func _end_cohen_sutherland() -> void:
	_cs_active = false
	_set_obstacles_invisible(false)

func _set_obstacles_invisible(is_inv: bool) -> void:
	if not spawner:
		return
	for child in spawner.get_children():
		if not is_instance_valid(child):
			continue
		# Never affect collectibles, power-up badges, or gravity corridor structures
		if child.has_signal("picked_up") or child.get_script() == AlgoPowerUpScript or child.has_signal("gravity_changed"):
			continue
		if child is Area2D or child is StaticBody2D or child.has_method("get_obstacle_type"):
			if is_inv:
				child.modulate.a = 0.06  # Faint phantom outline, completely transparent to run through
				for col in child.find_children("", "CollisionShape2D", true, false):
					col.set_deferred("disabled", true)
			else:
				child.modulate.a = 1.0
				for col in child.find_children("", "CollisionShape2D", true, false):
					col.set_deferred("disabled", false)

## 1: Purple: Matrix Surge slow Engine.time_scale for 2.0 seconds countdown.
func _apply_matrix_surge() -> void:
	_surge_active = true
	Engine.time_scale = 0.35

## 2: Green: Chaser Banish remove chaser for 4.0 seconds.
func _apply_chaser_banish() -> void:
	if chaser and chaser.has_method("banish"):
		chaser.banish(4.0)
	elif not chaser and get_tree() and get_tree().root:
		var c = get_tree().root.find_child("Chaser", true, false)
		if c and c.has_method("banish"):
			c.banish(4.0)

## 3: Orange: Coin Magnet pulls nearby coins & diamonds towards player for 2.5s.
func _apply_coin_magnet() -> void:
	_magnet_active = true

# ── HUD Helpers ───────────────────────────────────────────────

func _update_hud(frac: float) -> void:
	if not _hud_bar:
		return
	_hud_label.text = "[ %s ]" % _active_name
	_hud_label.add_theme_color_override("font_color", _active_color)
	_hud_fill.color = Color(_active_color.r, _active_color.g, _active_color.b, 0.22 * frac + 0.04)
	_hud_fill.size  = Vector2(320.0 * frac, 54.0)

	var dur : float = DURATIONS[_active_type] if _active_type >= 0 else 0.0
	if dur > 0.0:
		_hud_timer_lbl.text = "%.1fs remaining" % maxf(_active_timer, 0.0)
	else:
		_hud_timer_lbl.text = "ACTIVE"

func _update_hud_queue() -> void:
	if not _hud_queue_lbl:
		return
	var q_str : String = ""
	for t in _queue:
		q_str += "[%s] " % TYPE_NAMES[t]
	_hud_queue_lbl.text = q_str.strip_edges()

func reset() -> void:
	_queue.clear()
	_active_timer = 0.0
	_active_type  = -1
	if _hud_bar:
		_hud_bar.visible = false
	if _surge_active:
		Engine.time_scale = 1.0
		_surge_active = false
	_magnet_active = false
	if _cs_active:
		_end_cohen_sutherland()
