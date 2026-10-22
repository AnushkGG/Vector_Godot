## GravityZone.gd
## Area2D corridor that flips gravity when the player enters / exits.
## CG backing: reflection matrix about horizontal axis  [ 1  0 | 0 -1 ]
## Provides an overhead magnetic ceiling runner rail (StaticBody2D)
## so the player can run upside down along the top of the corridor.
extends Area2D
class_name GravityZone

signal gravity_changed(is_inverted: bool)

## Width of the gravity-flip corridor in world pixels.
@export var zone_width  : float = 1100.0
## Height -- symmetrical around camera baseline (560 - 340 = 220 px)
@export var zone_height : float = 340.0

var is_inverted : bool = true

# Visual timers for animated warning strips
var _anim_t     : float = 0.0
var _zone_color : Color = Color(0.58, 0.0, 1.0, 0.14)   # subtle purple field fill
var _ceil_body  : StaticBody2D

func _ready() -> void:
	# 1. Trigger Area2D collision shape (covers full corridor)
	var col := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(zone_width, zone_height)
	col.shape = shp
	col.position = Vector2(zone_width * 0.5, -zone_height * 0.5)
	add_child(col)

	# 2. Ceiling runner platform (StaticBody2D) for player to land and run on when inverted
	_ceil_body = StaticBody2D.new()
	_ceil_body.name = "CeilingRail"
	var ceil_col := CollisionShape2D.new()
	var ceil_shp := RectangleShape2D.new()
	ceil_shp.size = Vector2(zone_width, 24.0)
	ceil_col.shape = ceil_shp
	# Position at top of corridor: bottom of rail is at y = -zone_height
	ceil_col.position = Vector2(zone_width * 0.5, -zone_height - 12.0)
	_ceil_body.add_child(ceil_col)
	add_child(_ceil_body)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		gravity_changed.emit(true)

func _on_body_exited(body: Node) -> void:
	if body.name == "Player":
		gravity_changed.emit(false)

func _draw() -> void:
	# 1. Ambient anti-gravity field fill
	var fill_rect := Rect2(0.0, -zone_height, zone_width, zone_height)
	draw_rect(fill_rect, _zone_color)

	# 2. Overhead Cyberpunk Mag-Rail (the inverted ceiling floor)
	var rail_rect := Rect2(0.0, -zone_height - 20.0, zone_width, 20.0)
	draw_rect(rail_rect, Color(0.08, 0.06, 0.16, 0.95))
	# Glowing bottom edge of rail (where player's feet touch)
	draw_line(Vector2(0.0, -zone_height), Vector2(zone_width, -zone_height), Color(0.70, 0.15, 1.0, 0.9), 3.0)
	draw_line(Vector2(0.0, -zone_height + 2.0), Vector2(zone_width, -zone_height + 2.0), Color(0.0, 0.92, 1.0, 0.6), 1.5)

	# Mag-lev emitters every 80 px along ceiling rail
	var emitter_gap : float = 80.0
	var count : int = int(zone_width / emitter_gap)
	for i in range(count + 1):
		var ex : float = i * emitter_gap
		var pulse : float = 0.5 + 0.5 * sin(_anim_t * 5.0 + i * 0.5)
		draw_circle(Vector2(ex, -zone_height - 6.0), 3.5, Color(0.00, 0.92, 1.00, pulse))
		# Little vertical mag-suspension beam
		draw_line(Vector2(ex, -zone_height), Vector2(ex, -zone_height + 14.0), Color(0.58, 0.0, 1.0, pulse * 0.7), 1.5)

	# 3. Animated boundary warning strips
	_draw_warning_strip(0.0, true)
	_draw_warning_strip(zone_width, false)

	# 4. Inversion indicator arrows floating inside field
	var arrow_step : float = 220.0
	var num_arrows : int = int(zone_width / arrow_step)
	for i in range(1, num_arrows):
		var ax : float = i * arrow_step
		var bob : float = sin(_anim_t * 3.0 + i) * 6.0
		var ay : float = -zone_height * 0.5 + bob
		var arr_col := Color(0.70, 0.20, 1.00, 0.45)
		# Upward pointing arrow (indicating gravity vector flipped upward)
		var pts := PackedVector2Array([
			Vector2(ax, ay - 14.0),
			Vector2(ax - 10.0, ay + 6.0),
			Vector2(ax + 10.0, ay + 6.0)
		])
		draw_colored_polygon(pts, arr_col)

func _draw_warning_strip(x: float, is_entry: bool) -> void:
	var dash_h   : float = 24.0
	var gap_h    : float = 12.0
	var stripe_h : float = dash_h + gap_h
	var scroll   : float = fmod(_anim_t * 40.0, stripe_h)
	var strip_w  : float = 8.0

	var num_stripes : int = int(zone_height / stripe_h) + 2
	for i in range(num_stripes):
		var y_start : float = -zone_height + i * stripe_h - scroll
		if y_start + dash_h < -zone_height or y_start > 0.0:
			continue
		var col : Color = Color(0.70, 0.15, 1.00, 0.85) if (i % 2 == 0) else Color(0.00, 0.92, 1.00, 0.85)
		draw_rect(Rect2(x - strip_w * 0.5, y_start, strip_w, dash_h), col)

	# Entry chevron badge
	var mid_y : float = -zone_height * 0.5
	var pulse : float = 0.7 + 0.3 * sin(_anim_t * 4.0)
	var badge_col := Color(0.00, 0.92, 1.00, pulse) if is_entry else Color(0.70, 0.15, 1.00, pulse)
	var badge_pts := PackedVector2Array([
		Vector2(x, mid_y - 18.0),
		Vector2(x - 9.0, mid_y + 2.0),
		Vector2(x + 9.0, mid_y + 2.0)
	])
	draw_colored_polygon(badge_pts, badge_col)
