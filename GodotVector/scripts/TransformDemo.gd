extends Node2D
class_name TransformDemo

@export var rotation_speed : float = 1.2
@export var translate_amp  : float = 40.0
@export var scale_speed    : float = 0.9

var _time      : float = 0.0
var _show_demo : bool  = false

static func mat_translate(tx: float, ty: float) -> Array:
	return [[1.0, 0.0, tx], [0.0, 1.0, ty], [0.0, 0.0, 1.0]]

static func mat_rotate(angle: float) -> Array:
	var c := cos(angle);  var s := sin(angle)
	return [[ c, -s, 0.0], [ s,  c, 0.0], [0.0, 0.0, 1.0]]

static func mat_scale(sx: float, sy: float) -> Array:
	return [[sx, 0.0, 0.0], [0.0, sy, 0.0], [0.0, 0.0, 1.0]]

static func mat_mul(A: Array, B: Array) -> Array:
	var R : Array = [[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
	for i in range(3):
		for j in range(3):
			for k in range(3):
				R[i][j] += A[i][k] * B[k][j]
	return R

static func mat_apply(M: Array, pt: Vector2) -> Vector2:
	var x : float = M[0][0]*pt.x + M[0][1]*pt.y + M[0][2]
	var y : float = M[1][0]*pt.x + M[1][1]*pt.y + M[1][2]
	return Vector2(x, y)

static func transform_poly(M: Array, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mat_apply(M, p))
	return out

static func rotate_around(pts: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var M := mat_mul(mat_translate(pivot.x, pivot.y), mat_mul(mat_rotate(angle), mat_translate(-pivot.x, -pivot.y)))
	return transform_poly(M, pts)

static func scale_around(pts: PackedVector2Array, pivot: Vector2, sx: float, sy: float) -> PackedVector2Array:
	var M := mat_mul(mat_translate(pivot.x, pivot.y), mat_mul(mat_scale(sx, sy), mat_translate(-pivot.x, -pivot.y)))
	return transform_poly(M, pts)

var _base_diamond : PackedVector2Array = PackedVector2Array([Vector2(0.0,-20.0), Vector2(14.0,0.0), Vector2(0.0,20.0), Vector2(-14.0,0.0)])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_T or event.keycode == KEY_F1):
		_show_demo = not _show_demo
		queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _show_demo:
		queue_redraw()

func _draw() -> void:
	if not _show_demo:
		return
	var vp_size := get_viewport_rect().size
	var base := Vector2(vp_size.x - 130.0, 110.0)

	# Draw semi-transparent background HUD panel
	draw_rect(Rect2(base.x - 65.0, base.y - 70.0, 130.0, 150.0), Color(0.02, 0.02, 0.08, 0.85), true)
	draw_rect(Rect2(base.x - 65.0, base.y - 70.0, 130.0, 150.0), Color(0.0, 0.92, 0.98, 0.8), false, 1.0)

	var orig_pts : PackedVector2Array = PackedVector2Array()
	for v in _base_diamond:
		orig_pts.append(base + v)
	draw_polygon(orig_pts, PackedColorArray([Color(0.2, 0.2, 0.3, 0.6)]))

	# 1. Translation (Cyan)
	var tx : float = sin(_time * 1.5) * (translate_amp * 0.7)
	var ty : float = cos(_time * 1.5) * (translate_amp * 0.35)
	var T := mat_translate(tx, ty)
	var trans_pts := transform_poly(T, orig_pts)
	draw_polygon(trans_pts, PackedColorArray([Color(0.0, 0.96, 1.0, 0.45)]))
	draw_line(base, base + Vector2(tx, ty), Color(0.0, 0.96, 1.0, 0.7), 1.0)

	# 2. Rotation (Purple)
	var rot_pts := rotate_around(orig_pts, base, _time * rotation_speed)
	draw_polygon(rot_pts, PackedColorArray([Color(0.65, 0.20, 1.0, 0.45)]))

	# 3. Scaling (Yellow)
	var sc : float = 0.6 + sin(_time * scale_speed) * 0.35 + 0.35
	var scl_pts := scale_around(orig_pts, base, sc, sc)
	draw_polygon(scl_pts, PackedColorArray([Color(1.0, 0.9, 0.0, 0.4)]))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(base.x - 55.0, base.y - 52.0), "[F1/T] 2D TRANSFORMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.0, 0.92, 0.98, 1.0))
	draw_string(font, Vector2(base.x - 55.0, base.y + 42.0), "* Cyan: Translation", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.0, 0.96, 1.0, 0.9))
	draw_string(font, Vector2(base.x - 55.0, base.y + 54.0), "* Purple: Rotation", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.75, 0.35, 1.0, 0.9))
	draw_string(font, Vector2(base.x - 55.0, base.y + 66.0), "* Yellow: Scaling", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.9, 0.2, 0.9))
