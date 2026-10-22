## AlgoPowerUp.gd
## Collectible power-up node named after CG algorithms.
## 4 distinct power-ups:
## 0: Cyan   - Cohen-Sutherland Obstacle Vaporizer
## 1: Purple - Matrix Surge Bullet-Time Slowdown (2.5s)
## 2: Green  - Midpoint Disruptor / Chaser Banisher (4.0s)
## 3: Orange - Flood Fill Magnetic Coin Collector (2.5s)
extends Area2D
class_name AlgoPowerUp

signal collected(type: int)

enum PowerType {
	COHEN_SUTHERLAND,   ## 0: Cyan   - Obstacle Vaporizer
	MATRIX_SURGE,       ## 1: Purple - Slow Motion (2.5s)
	CHASER_BANISH,      ## 2: Green  - Banishes Chaser for 4.0s
	COIN_MAGNET         ## 3: Orange - Attracts Coins & Diamonds (2.5s)
}

@export var power_type : PowerType = PowerType.COHEN_SUTHERLAND

# Per-type color table
const TYPE_COLORS : Array[Color] = [
	Color(0.00, 0.92, 1.00),   # 0: CS - cyan
	Color(0.68, 0.10, 1.00),   # 1: MS - purple
	Color(0.10, 0.95, 0.30),   # 2: CB - green
	Color(1.00, 0.47, 0.00),   # 3: CM - orange
]

const TYPE_NAMES : Array[String] = [
	"COHEN-SUTHERLAND", "MATRIX SURGE", "CHASER BANISH", "COIN MAGNET"
]

var _anim_t     : float = 0.0
var _spin       : float = 0.0
var _bob_y      : float = 0.0
var _done       : bool  = false
var _col_shape  : CollisionShape2D

func _ready() -> void:
	# Build circular collision shape (radius 26)
	_col_shape = CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 26.0
	_col_shape.shape = shp
	add_child(_col_shape)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim_t += delta
	_spin   += delta * 1.8
	_bob_y   = sin(_anim_t * 2.5) * 7.0
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _done or body.name != "Player":
		return
	_done = true
	_col_shape.set_deferred("disabled", true)
	collected.emit(int(power_type))
	_play_pickup_anim()

func _play_pickup_anim() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await get_tree().create_timer(0.25).timeout
	queue_free()

func _draw() -> void:
	if _done:
		return
	var c  : Color = TYPE_COLORS[int(power_type) % 4]
	var cx : float = 0.0
	var cy : float = _bob_y

	match power_type:
		PowerType.COHEN_SUTHERLAND:
			_draw_cohen_sutherland(cx, cy, c)
		PowerType.MATRIX_SURGE:
			_draw_matrix_surge(cx, cy, c)
		PowerType.CHASER_BANISH:
			_draw_chaser_banish(cx, cy, c)
		PowerType.COIN_MAGNET:
			_draw_coin_magnet(cx, cy, c)

# ── 0: Cohen-Sutherland: diamond with 4 outcode region dividers ──────────────
func _draw_cohen_sutherland(cx: float, cy: float, c: Color) -> void:
	var r : float = 22.0
	var glow := Color(c.r, c.g, c.b, 0.25 + 0.15 * sin(_anim_t * 4.0))
	draw_circle(Vector2(cx, cy), r * 1.5, glow)
	# Spinning diamond (rotated square)
	var pts := PackedVector2Array()
	for i in 4:
		var a : float = _spin + i * PI / 2.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.35))
	draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0)
	# 4 outcode region lines (horizontal + vertical cross)
	var pulse : float = 0.6 + 0.4 * sin(_anim_t * 6.0)
	var lc := Color(1.0, 1.0, 1.0, pulse)
	draw_line(Vector2(cx - r, cy), Vector2(cx + r, cy), lc, 1.0)
	draw_line(Vector2(cx, cy - r), Vector2(cx, cy + r), lc, 1.0)
	draw_circle(Vector2(cx, cy), 3.0, c)

# ── 1: Matrix Surge: shearing grid (affine transform visualised) ─────────────
func _draw_matrix_surge(cx: float, cy: float, c: Color) -> void:
	var r   : float = 20.0
	var glow := Color(c.r, c.g, c.b, 0.22)
	draw_circle(Vector2(cx, cy), r * 1.5, glow)
	# Animated shear amount
	var shear : float = sin(_anim_t * 3.0) * 0.5
	var steps : int = 3
	var step  : float = r * 2.0 / float(steps)
	var grid_c := Color(c.r, c.g, c.b, 0.7)
	for i in range(steps + 1):
		var y : float = cy - r + i * step
		var x_off : float = shear * (y - cy)
		draw_line(Vector2(cx - r + x_off, y), Vector2(cx + r + x_off, y), grid_c, 1.0)
		draw_line(Vector2(cx - r + x_off, cy - r), Vector2(cx + r + x_off, cy + r), grid_c, 1.0)
	draw_circle(Vector2(cx, cy), 4.0, c)

# ── 2: Chaser Banish: green EMP barrier with electric pulses ────────────────
func _draw_chaser_banish(cx: float, cy: float, c: Color) -> void:
	var r : float = 22.0
	var glow := Color(c.r, c.g, c.b, 0.25 + 0.15 * sin(_anim_t * 5.0))
	draw_circle(Vector2(cx, cy), r * 1.6, glow)
	# Outer shield ring
	draw_arc(Vector2(cx, cy), r, 0, TAU, 32, c, 2.0)
	# Pulsing inner banish field
	var inner_r : float = r * (0.4 + 0.3 * sin(_anim_t * 4.0))
	draw_circle(Vector2(cx, cy), inner_r, Color(c.r, c.g, c.b, 0.3))
	# Disruption barrier crossbars
	var num_spikes : int = 6
	for i in range(num_spikes):
		var a : float = _spin * 1.5 + i * (TAU / num_spikes)
		var p1 := Vector2(cx + cos(a) * inner_r, cy + sin(a) * inner_r)
		var p2 := Vector2(cx + cos(a) * (r + 4.0), cy + sin(a) * (r + 4.0))
		draw_line(p1, p2, Color(1, 1, 1, 0.9), 1.5)
	draw_circle(Vector2(cx, cy), 3.5, Color.WHITE)

# ── 3: Coin Magnet: horseshoe magnetic arcs pulling in flux particles ───────
func _draw_coin_magnet(cx: float, cy: float, c: Color) -> void:
	var r : float = 22.0
	var glow := Color(c.r, c.g, c.b, 0.25)
	draw_circle(Vector2(cx, cy), r * 1.5, glow)
	# Dual magnetic horseshoe arcs
	draw_arc(Vector2(cx, cy), r, PI * 0.2 + _spin * 0.5, PI * 1.8 + _spin * 0.5, 24, c, 3.0)
	# Inward magnetic flux lines
	for i in range(4):
		var phase : float = fmod(_anim_t * 2.0 + float(i) * 0.25, 1.0)
		var in_r  : float = lerpf(r * 1.3, 4.0, phase)
		var a     : float = float(i) * (TAU / 4.0) + _spin * 0.5
		var alpha : float = sin(phase * PI) * 0.9
		draw_circle(Vector2(cx + cos(a) * in_r, cy + sin(a) * in_r), 2.5, Color(1.0, 0.85, 0.2, alpha))
	# Center magnetic core
	draw_circle(Vector2(cx, cy), 5.0, Color(1.0, 0.6, 0.0, 1.0))
