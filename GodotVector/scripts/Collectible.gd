extends Area2D
class_name Collectible

enum Type { COIN, DIAMOND }
@export var kind: Type = Type.COIN

signal picked_up(kind: int)   # emits Collectible.Type value

var _done    := false
var _bob_t   : float = 0.0
var _glow_t  : float = 0.0
var _spin_angle : float = 0.0

# ── Shape parameters ───────────────────────────────────────────
## Data Crystal (COIN): hexagon, bright electric cyan
const CRYSTAL_R     : float = 14.0
const CRYSTAL_SIDES : int   = 6
const CRYSTAL_COL   : Color = Color(0.00, 0.96, 1.00, 1.0)
const CRYSTAL_HI    : Color = Color(0.85, 1.00, 1.00, 1.0)
const CRYSTAL_GLOW  : Color = Color(0.00, 0.92, 0.98, 0.45)

## Power Core (DIAMOND): octagon, vivid neon purple
const CORE_R        : float = 16.0
const CORE_SIDES    : int   = 8
const CORE_COL      : Color = Color(0.70, 0.15, 1.00, 1.0)
const CORE_HI       : Color = Color(1.00, 0.85, 1.00, 1.0)
const CORE_GLOW     : Color = Color(0.65, 0.12, 1.00, 0.40)

func _ready() -> void:
	body_entered.connect(_on_body)
	if has_node("Sprite2D"):
		get_node("Sprite2D").visible = false

func _process(delta: float) -> void:
	_bob_t      += delta * 2.8
	_glow_t     += delta * 3.5
	_spin_angle += delta * 2.4
	queue_redraw()

func _on_body(body: Node) -> void:
	if _done or body.name != "Player": return
	_done = true
	picked_up.emit(kind)
	_play_pickup()
	await get_tree().create_timer(0.25).timeout
	queue_free()

func _play_pickup() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.4, 2.4), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)

func _draw() -> void:
	if _done:
		return

	var bob_y : float = sin(_bob_t) * 5.0
	var glow  : float = 0.5 + sin(_glow_t) * 0.5

	# Screen-space viewport clip rect for Sutherland-Hodgman polygon clipping
	var screen_pos := get_global_transform_with_canvas().origin
	var vp_size    := get_viewport_rect().size
	var vp_clip    := Rect2(-screen_pos.x, -screen_pos.y, vp_size.x, vp_size.y)

	if kind == Type.COIN:
		_draw_crystal(bob_y, glow, vp_clip)
	else:
		_draw_core(bob_y, glow, vp_clip)

## Generates base polygon centered at origin (0,0)
func _make_base_poly(n: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var angle : float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts

func _draw_crystal(bob_y: float, glow: float, vp_clip: Rect2) -> void:
	var r : float = CRYSTAL_R
	var pulse : float = 1.0 + 0.12 * sin(_bob_t * 2.0)

	# 2D Transformations: Mat3 homogeneous matrix pipeline: F = (S * R) * T
	var S := ClipAlgorithms.mat_scaling(pulse, pulse)
	var R := ClipAlgorithms.mat_rotation(_spin_angle)
	var T := ClipAlgorithms.mat_translation(0.0, bob_y)
	var M := ClipAlgorithms.mat_multiply(ClipAlgorithms.mat_multiply(S, R), T)

	# 1. Outer Glow (Hexagon) -> Transformed by M -> Clipped by Sutherland-Hodgman
	var glow_base := _make_base_poly(CRYSTAL_SIDES, r * 1.6)
	var glow_xformed := ClipAlgorithms.transform_polygon(M, glow_base)
	var glow_clipped := ClipAlgorithms.clip_polygon_to_rect(glow_xformed, vp_clip)
	if glow_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		glow_clipped = glow_xformed
	if glow_clipped.size() >= 3:
		var glow_col := Color(CRYSTAL_GLOW.r, CRYSTAL_GLOW.g, CRYSTAL_GLOW.b, CRYSTAL_GLOW.a * glow)
		draw_polygon(glow_clipped, PackedColorArray([glow_col]))

	# 2. Main Crystal Body (Hexagon) -> Transformed by M -> Clipped
	var main_base := _make_base_poly(CRYSTAL_SIDES, r)
	var main_xformed := ClipAlgorithms.transform_polygon(M, main_base)
	var main_clipped := ClipAlgorithms.clip_polygon_to_rect(main_xformed, vp_clip)
	if main_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		main_clipped = main_xformed
	if main_clipped.size() >= 3:
		draw_polygon(main_clipped, PackedColorArray([CRYSTAL_COL]))
		draw_polyline(main_clipped + PackedVector2Array([main_clipped[0]]), CRYSTAL_HI, 1.4)

	# 3. Inner Facet (Counter-rotating nested hexagon)
	var R_inner := ClipAlgorithms.mat_rotation(-_spin_angle * 1.5)
	var M_inner := ClipAlgorithms.mat_multiply(ClipAlgorithms.mat_multiply(S, R_inner), T)
	var inner_base := _make_base_poly(CRYSTAL_SIDES, r * 0.45)
	var inner_xformed := ClipAlgorithms.transform_polygon(M_inner, inner_base)
	var inner_clipped := ClipAlgorithms.clip_polygon_to_rect(inner_xformed, vp_clip)
	if inner_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		inner_clipped = inner_xformed
	if inner_clipped.size() >= 3:
		draw_polygon(inner_clipped, PackedColorArray([CRYSTAL_HI]))

func _draw_core(bob_y: float, glow: float, vp_clip: Rect2) -> void:
	var r : float = CORE_R
	var pulse : float = 1.0 + 0.15 * sin(_bob_t * 2.5)

	# 2D Transformations: Mat3 homogeneous matrix pipeline: F = (S * R) * T
	var S := ClipAlgorithms.mat_scaling(pulse, pulse)
	var R := ClipAlgorithms.mat_rotation(_spin_angle)
	var T := ClipAlgorithms.mat_translation(0.0, bob_y)
	var M := ClipAlgorithms.mat_multiply(ClipAlgorithms.mat_multiply(S, R), T)

	# 1. Outer Glow (Octagon) -> Transformed by M -> Clipped by Sutherland-Hodgman
	var glow_base := _make_base_poly(CORE_SIDES, r * 1.65)
	var glow_xformed := ClipAlgorithms.transform_polygon(M, glow_base)
	var glow_clipped := ClipAlgorithms.clip_polygon_to_rect(glow_xformed, vp_clip)
	if glow_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		glow_clipped = glow_xformed
	if glow_clipped.size() >= 3:
		var glow_col := Color(CORE_GLOW.r, CORE_GLOW.g, CORE_GLOW.b, CORE_GLOW.a * glow)
		draw_polygon(glow_clipped, PackedColorArray([glow_col]))

	# 2. Main Octagon Body -> Transformed by M -> Clipped
	var main_base := _make_base_poly(CORE_SIDES, r)
	var main_xformed := ClipAlgorithms.transform_polygon(M, main_base)
	var main_clipped := ClipAlgorithms.clip_polygon_to_rect(main_xformed, vp_clip)
	if main_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		main_clipped = main_xformed
	if main_clipped.size() >= 3:
		draw_polygon(main_clipped, PackedColorArray([CORE_COL]))
		draw_polyline(main_clipped + PackedVector2Array([main_clipped[0]]), CORE_HI, 1.4)

	# 3. Inner Core Star (Fast-spinning internal crystal)
	var R_inner := ClipAlgorithms.mat_rotation(-_spin_angle * 2.0)
	var M_inner := ClipAlgorithms.mat_multiply(ClipAlgorithms.mat_multiply(S, R_inner), T)
	var inner_base := _make_base_poly(CORE_SIDES, r * 0.42)
	var inner_xformed := ClipAlgorithms.transform_polygon(M_inner, inner_base)
	var inner_clipped := ClipAlgorithms.clip_polygon_to_rect(inner_xformed, vp_clip)
	if inner_clipped.size() < 3 and vp_clip.has_point(Vector2.ZERO):
		inner_clipped = inner_xformed
	if inner_clipped.size() >= 3:
		draw_polygon(inner_clipped, PackedColorArray([CORE_HI]))
