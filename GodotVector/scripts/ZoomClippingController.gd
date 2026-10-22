## ZoomClippingController.gd
## Implements Camera Zoom as a direct application of 2D Window-to-Viewport Clipping.
##
## In Computer Graphics:
##   Zooming changes the size of the World Clipping Window [xmin, ymin, xmax, ymax].
##   As the window shrinks (zoom in) or expands (zoom out), lines and polygons
##   cross the boundary edges and MUST be clipped dynamically.
##
## Algorithms demonstrated:
##   1. Cohen-Sutherland Line Clipping (Region outcodes: 0000, 0001, 0010, 0100, 1000)
##   2. Liang-Barsky Line Clipping (Parametric inequalities: pk, qk)
##   3. Midpoint Subdivision Line Clipping (Recursive bisection search)
##   4. Sutherland-Hodgman Polygon Clipping (4-plane polygon clipping pipeline)
##   5. Intersection Crossing Markers (Red crosses at boundary intersections, as in ass5.cpp)
##
## Controls:
##   [Z] Cycle Camera Zoom: 1.0x (Standard) -> 1.6x (Tactical Zoom) -> 0.75x (Wide View)
##   [G] Cycle Line Clipping Algorithm (Cohen-Sutherland / Liang-Barsky / Midpoint)
##   [C] Toggle Tactical Clipping Reticle & Diagnostic HUD

extends Node2D
class_name ZoomClippingController

enum ZoomLevel { NORMAL, TACTICAL_ZOOM, WIDE_VIEW }
var zoom_mode : ZoomLevel = ZoomLevel.NORMAL

const ZOOM_VALUES : Array[float] = [1.0, 1.6, 0.75]
const ZOOM_NAMES  : Array[String] = ["1.0x (Standard)", "1.6x (Tactical Zoom)", "0.75x (Wide Overview)"]

enum ClipAlgorithm { COHEN_SUTHERLAND, LIANG_BARSKY, MIDPOINT }
var clip_algo : ClipAlgorithm = ClipAlgorithm.COHEN_SUTHERLAND
const ALGO_NAMES : Array[String] = ["Cohen-Sutherland", "Liang-Barsky", "Midpoint Subdivision"]

var _show_overlay     : bool  = true
var _camera           : Camera2D
var _player           : CharacterBody2D
var _tween            : Tween
var _time             : float = 0.0

## Cached intersection points from the most recent frame's clipping pass
var _active_crossings : PackedVector2Array = PackedVector2Array()
var _intersections_count : int = 0
var _rejected_count     : int = 0

## Interactive HUD button
var _zoom_button : Button

func _ready() -> void:
	z_index = 20
	_find_references()
	_create_hud_button()

func _find_references() -> void:
	if not _player:
		_player = get_tree().root.find_child("Player", true, false) as CharacterBody2D
	if not _camera and _player:
		_camera = _player.get_node_or_null("Camera2D") as Camera2D

func _create_hud_button() -> void:
	_zoom_button = Button.new()
	_zoom_button.name = "ZoomButton"
	_zoom_button.text = "[Z] ZOOM: 1.0x"
	_zoom_button.position = Vector2(20.0, 125.0)
	_zoom_button.size = Vector2(170.0, 32.0)
	_zoom_button.focus_mode = Control.FOCUS_NONE
	
	# Cyber styling for the button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.18, 0.85)
	style.border_color = Color(0.00, 0.92, 0.98, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	_zoom_button.add_theme_stylebox_override("normal", style)
	_zoom_button.add_theme_stylebox_override("hover", style)
	_zoom_button.add_theme_stylebox_override("pressed", style)
	_zoom_button.add_theme_color_override("font_color", Color(0.00, 0.92, 0.98, 1.0))
	_zoom_button.add_theme_font_size_override("font_size", 13)
	_zoom_button.pressed.connect(_cycle_zoom)
	add_child(_zoom_button)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z:
			_cycle_zoom()
		elif event.keycode == KEY_G:
			_cycle_algorithm()
		elif event.keycode == KEY_C:
			_show_overlay = not _show_overlay
			queue_redraw()

func _cycle_zoom() -> void:
	_find_references()
	zoom_mode = ZoomLevel.values()[(int(zoom_mode) + 1) % ZoomLevel.size()]
	var target_zoom_val : float = ZOOM_VALUES[int(zoom_mode)]
	
	if _camera:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC)
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(_camera, "zoom", Vector2(target_zoom_val, target_zoom_val), 0.35)
	
	if _zoom_button:
		_zoom_button.text = "[Z] ZOOM: %.2fx" % target_zoom_val
	
	queue_redraw()

func _cycle_algorithm() -> void:
	clip_algo = ClipAlgorithm.values()[(int(clip_algo) + 1) % ClipAlgorithm.size()]
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _show_overlay:
		queue_redraw()

func _draw() -> void:
	if not _show_overlay:
		return

	var vp_size : Vector2 = get_viewport_rect().size
	var W : float = vp_size.x
	var H : float = vp_size.y

	# Calculate dynamic screen clipping window margins based on zoom mode
	# In Tactical Zoom, we visually frame the active focus region
	var clip_margin : Vector2
	match zoom_mode:
		ZoomLevel.TACTICAL_ZOOM:
			clip_margin = Vector2(W * 0.12, H * 0.12) # Shrunk window: heavy clipping!
		ZoomLevel.WIDE_VIEW:
			clip_margin = Vector2(W * 0.02, H * 0.02) # Wide window
		_:
			clip_margin = Vector2(W * 0.05, H * 0.05) # Standard window

	var clip_rect := Rect2(clip_margin, vp_size - clip_margin * 2.0)
	var xmin : float = clip_rect.position.x
	var xmax : float = clip_rect.position.x + clip_rect.size.x
	var ymin : float = clip_rect.position.y
	var ymax : float = clip_rect.position.y + clip_rect.size.y

	# 1. Draw Viewfinder Boundary Box & Corner Reticles
	var frame_color : Color
	match zoom_mode:
		ZoomLevel.TACTICAL_ZOOM:
			frame_color = Color(1.00, 0.25, 0.45, 0.85) # Vivid Cyber Red/Pink for Tactical Focus
		ZoomLevel.WIDE_VIEW:
			frame_color = Color(0.65, 0.20, 1.00, 0.75) # Cyber Violet
		_:
			frame_color = Color(0.00, 0.92, 0.98, 0.65) # Cyan standard

	# Boundary outline (subtle dashed/thin border)
	draw_rect(clip_rect, Color(frame_color.r, frame_color.g, frame_color.b, 0.25), false, 1.0)

	# High-tech corner brackets
	var bracket_len : float = 24.0
	var bw : float = 2.0
	# Top-Left
	draw_line(Vector2(xmin, ymin), Vector2(xmin + bracket_len, ymin), frame_color, bw)
	draw_line(Vector2(xmin, ymin), Vector2(xmin, ymin + bracket_len), frame_color, bw)
	# Top-Right
	draw_line(Vector2(xmax, ymin), Vector2(xmax - bracket_len, ymin), frame_color, bw)
	draw_line(Vector2(xmax, ymin), Vector2(xmax, ymin + bracket_len), frame_color, bw)
	# Bottom-Left
	draw_line(Vector2(xmin, ymax), Vector2(xmin + bracket_len, ymax), frame_color, bw)
	draw_line(Vector2(xmin, ymax), Vector2(xmin, ymax - bracket_len), frame_color, bw)
	# Bottom-Right
	draw_line(Vector2(xmax, ymax), Vector2(xmax - bracket_len, ymax), frame_color, bw)
	draw_line(Vector2(xmax, ymax), Vector2(xmax, ymax - bracket_len), frame_color, bw)

	# 2. Line Clipping Demonstration (Scanner rays swept across clipping window)
	_active_crossings.clear()
	_intersections_count = 0
	_rejected_count = 0

	var num_rays : int = 7
	for i in range(num_rays):
		var t : float = float(i) / float(num_rays - 1)
		var angle : float = _time * 0.5 + t * PI
		var center := clip_rect.position + clip_rect.size * 0.5
		var ray_len : float = maxf(W, H) * 0.65
		var p1 := center - Vector2(cos(angle), sin(angle)) * ray_len
		var p2 := center + Vector2(cos(angle), sin(angle)) * ray_len

		# Test line clipping with the selected algorithm
		var clipped : PackedVector2Array = _run_line_clip(p1, p2, clip_rect)

		if clipped.size() == 2:
			# Line visibly crosses the boundary: draw the inside portion in bright neon
			var ray_col := Color(frame_color.r, frame_color.g, frame_color.b, 0.35 + 0.15 * sin(_time * 3.0 + t))
			draw_line(clipped[0], clipped[1], ray_col, 1.2)

			# Record and mark intersection crossings if p1 or p2 was trimmed by the boundary
			if clipped[0].distance_to(p1) > 1.0:
				_active_crossings.append(clipped[0])
				_intersections_count += 1
			if clipped[1].distance_to(p2) > 1.0:
				_active_crossings.append(clipped[1])
				_intersections_count += 1
		else:
			_rejected_count += 1

	# 3. Draw Red Intersection Crossing Marks (+) — as in Assignment 5 markCrossings()
	var cross_col := Color(1.0, 0.20, 0.20, 0.95)
	for cross_pt in _active_crossings:
		draw_line(cross_pt - Vector2(5.0, 0.0), cross_pt + Vector2(5.0, 0.0), cross_col, 1.5)
		draw_line(cross_pt - Vector2(0.0, 5.0), cross_pt + Vector2(0.0, 5.0), cross_col, 1.5)
		draw_circle(cross_pt, 1.5, Color(1.0, 1.0, 1.0, 0.9))

	# 4. Sutherland-Hodgman Polygon Clipping Demonstration
	# An orbiting cyber data crystal clipped dynamically against the top-right of the window
	var poly_center := Vector2(xmax - 45.0, ymin + 45.0) + Vector2(cos(_time * 1.5), sin(_time * 1.5)) * 25.0
	var poly_base := PackedVector2Array([
		poly_center + Vector2(0.0, -22.0),
		poly_center + Vector2(22.0, -7.0),
		poly_center + Vector2(14.0, 22.0),
		poly_center + Vector2(-14.0, 22.0),
		poly_center + Vector2(-22.0, -7.0)
	])
	var poly_clipped := ClipAlgorithms.clip_polygon_to_rect(poly_base, clip_rect)
	if poly_clipped.size() >= 3:
		draw_polygon(poly_clipped, PackedColorArray([Color(0.00, 0.95, 0.75, 0.4)]))
		draw_polyline(poly_clipped + PackedVector2Array([poly_clipped[0]]), Color(0.00, 1.00, 0.80, 0.9), 1.5)
		# Draw yellow dots at clipped vertices
		for v in poly_clipped:
			draw_circle(v, 2.0, Color(1.0, 0.9, 0.2, 0.95))

	# 5. Diagnostic Cyber HUD Panel (Top-Right)
	_draw_diagnostic_hud(W, H, clip_rect)

func _run_line_clip(p1: Vector2, p2: Vector2, rect: Rect2) -> PackedVector2Array:
	match clip_algo:
		ClipAlgorithm.COHEN_SUTHERLAND:
			return ClipAlgorithms.cohen_sutherland(p1, p2, rect)
		ClipAlgorithm.LIANG_BARSKY:
			return ClipAlgorithms.liang_barsky(p1, p2, rect)
		ClipAlgorithm.MIDPOINT:
			return ClipAlgorithms.midpoint_subdivision(p1, p2, rect, 16)
	return PackedVector2Array()

func _draw_diagnostic_hud(W: float, _H: float, clip_rect: Rect2) -> void:
	var hud_w : float = 330.0
	var hud_h : float = 120.0
	var hud_x : float = W - hud_w - 20.0
	var hud_y : float = 20.0

	# Dark glassmorphic background
	draw_rect(Rect2(hud_x, hud_y, hud_w, hud_h), Color(0.02, 0.04, 0.10, 0.88), true)
	draw_rect(Rect2(hud_x, hud_y, hud_w, hud_h), Color(0.00, 0.92, 0.98, 0.75), false, 1.0)
	# Accent top strip
	draw_rect(Rect2(hud_x, hud_y, hud_w, 2.0), Color(0.00, 0.92, 0.98, 0.95))

	var font := ThemeDB.fallback_font
	var c_cyan := Color(0.00, 0.92, 0.98, 1.0)
	var c_dim  := Color(0.75, 0.85, 0.95, 0.85)
	var c_hi   := Color(1.00, 0.85, 0.20, 1.0)
	var c_red  := Color(1.00, 0.35, 0.35, 0.95)

	var title_text := "CGG CLIPPING ENGINE  |  %s" % ZOOM_NAMES[int(zoom_mode)]
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 18.0), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c_cyan)

	var rect_text := "Clip Window: [X: %.0f..%.0f  Y: %.0f..%.0f]" % [
		clip_rect.position.x, clip_rect.position.x + clip_rect.size.x,
		clip_rect.position.y, clip_rect.position.y + clip_rect.size.y
	]
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 36.0), rect_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_dim)

	var algo_text := "Line Clip [G]: %s" % ALGO_NAMES[int(clip_algo)]
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 54.0), algo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_hi)

	var poly_text := "Poly Clip: Sutherland-Hodgman (4-Plane)"
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 72.0), poly_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_dim)

	var stats_text := "Boundary Crossings (+): %d  |  Culled: %d" % [_intersections_count, _rejected_count]
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 90.0), stats_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_red)

	var keys_text := "[Z] Zoom  [G] Switch Algo  [C] Reticle Toggle"
	draw_string(font, Vector2(hud_x + 10.0, hud_y + 108.0), keys_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.7, 0.9, 0.75))
