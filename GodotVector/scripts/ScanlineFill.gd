## ScanlineFill.gd
## Implements low-level Scanline Polygon Filling & Rasterization Algorithms for Computer Graphics.
##
## Theoretical Concepts Implemented (Assignment 2):
##   1. Edge Table (ET):
##      - Bucketed by edge minimum y (y_min)
##      - Stores: [y_max, x_min, 1/m]
##      - Horizontal edges (dy = 0) are excluded
##   2. Active Edge Table (AET):
##      - Tracks all edges intersecting current scanline y
##      - Sorted in ascending order of current x-intersection
##   3. Incremental x calculation:
##      - x_{k+1} = x_k + (1 / m), where 1/m = dx / dy
##      - Avoids floating-point line equation evaluations per pixel
##   4. Parity Rule (Odd-Even Rule):
##      - Pixels between paired intersections [x1, x2], [x3, x4] are filled
##   5. Vertex Extremum Handling:
##      - Monotonic vertices shortened by 1 to prevent double-counting
##   6. Boundary Fill & Flood Fill:
##      - 4-connected recursive region coloring

class_name ScanlineFill
extends RefCounted

## Represents an entry in the Edge Table and Active Edge Table
class EdgeEntry:
	var y_max     : float   ## Maximum y-extent of edge
	var x_current : float   ## Current x-intersection along scanline
	var inv_slope : float   ## 1/m = (x2 - x1) / (y2 - y1)

	func _init(p_ymax: float, p_xmin: float, p_inv_slope: float) -> void:
		y_max = p_ymax
		x_current = p_xmin
		inv_slope = p_inv_slope

## -----------------------------------------------------------------------------
## SCANLINE POLYGON FILL ALGORITHM
## -----------------------------------------------------------------------------

## Computes scanline spans for any arbitrary 2D polygon.
## Returns Array of dictionaries: [{ "y": float, "spans": Array of [x_start, x_end] }]
static func compute_scanline_spans(vertices: PackedVector2Array) -> Array:
	var n : int = vertices.size()
	if n < 3:
		return []

	# 1. Determine bounding y-range of the polygon
	var min_poly_y : int = int(ceil(vertices[0].y))
	var max_poly_y : int = int(floor(vertices[0].y))
	for v in vertices:
		min_poly_y = mini(min_poly_y, int(ceil(v.y)))
		max_poly_y = maxi(max_poly_y, int(floor(v.y)))

	# 2. Build Edge Table (ET) bucketed by y_min
	var edge_table : Dictionary = {}
	for y in range(min_poly_y, max_poly_y + 1):
		edge_table[y] = []

	for i in range(n):
		var p1 : Vector2 = vertices[i]
		var p2 : Vector2 = vertices[(i + 1) % n]

		# Skip horizontal edges (dy == 0)
		if is_equal_approx(p1.y, p2.y):
			continue

		var v_low  : Vector2 = p1 if p1.y < p2.y else p2
		var v_high : Vector2 = p2 if p1.y < p2.y else p1

		var dy : float = v_high.y - v_low.y
		var dx : float = v_high.x - v_low.x
		var inv_slope : float = dx / dy  # 1 / m

		var y_start : int = int(ceil(v_low.y))
		var y_end   : float = v_high.y

		# Calculate initial x at first integer scanline
		var initial_x : float = v_low.x + (float(y_start) - v_low.y) * inv_slope

		var entry := EdgeEntry.new(y_end, initial_x, inv_slope)
		if not edge_table.has(y_start):
			edge_table[y_start] = []
		edge_table[y_start].append(entry)

	# 3. Process Scanlines using Active Edge Table (AET)
	var active_edge_table : Array = []
	var result_spans : Array = []

	for y in range(min_poly_y, max_poly_y + 1):
		# A. Add newly active edges from ET[y] into AET
		if edge_table.has(y):
			for edge in edge_table[y]:
				active_edge_table.append(edge)

		# B. Remove edges whose y_max <= current scanline y
		var remaining_aet : Array = []
		for edge in active_edge_table:
			if edge.y_max > float(y):
				remaining_aet.append(edge)
		active_edge_table = remaining_aet

		if active_edge_table.is_empty():
			continue

		# C. Sort AET by current x-intersection (ascending)
		active_edge_table.sort_custom(func(a: EdgeEntry, b: EdgeEntry) -> bool:
			return a.x_current < b.x_current
		)

		# D. Apply Parity Rule (fill spans between odd-even pairs: [x0, x1], [x2, x3], ...)
		var spans_at_y : Array = []
		var count : int = active_edge_table.size()
		var i : int = 0
		while i + 1 < count:
			var x_start : float = active_edge_table[i].x_current
			var x_end   : float = active_edge_table[i + 1].x_current
			if x_end >= x_start:
				spans_at_y.append(Vector2(x_start, x_end))
			i += 2

		if not spans_at_y.is_empty():
			result_spans.append({ "y": y, "spans": spans_at_y })

		# E. Incrementally advance x for all active edges: x_{k+1} = x_k + 1/m
		for edge in active_edge_table:
			edge.x_current += edge.inv_slope

	return result_spans

## Rasterizes polygon directly onto a Godot CanvasItem using scanline spans.
## Demonstrates procedural scanline rendering without built-in polygon rasterizers.
static func rasterize_polygon_scanline(canvas: CanvasItem, polygon: PackedVector2Array, color: Color) -> void:
	var span_data : Array = compute_scanline_spans(polygon)
	for line_info in span_data:
		var y : float = float(line_info["y"])
		var spans : Array = line_info["spans"]
		for span in spans:
			var x1 : float = span.x
			var x2 : float = span.y
			canvas.draw_line(Vector2(x1, y), Vector2(x2, y), color, 1.0)

## -----------------------------------------------------------------------------
## BOUNDARY FILL & FLOOD FILL ALGORITHMS (Region-Based Filling)
## -----------------------------------------------------------------------------

## 4-Connected Boundary Fill:
## Recursively colors enclosed region until boundary color is encountered.
static func boundary_fill_4(image: Image, x: int, y: int, fill_color: Color, boundary_color: Color, max_depth: int = 10000) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return
	var stack : Array[Vector2i] = [Vector2i(x, y)]
	var visited_count : int = 0

	while not stack.is_empty() and visited_count < max_depth:
		var pt : Vector2i = stack.pop_back()
		visited_count += 1
		if pt.x < 0 or pt.x >= image.get_width() or pt.y < 0 or pt.y >= image.get_height():
			continue

		var current_color : Color = image.get_pixel(pt.x, pt.y)
		if not current_color.is_equal_approx(boundary_color) and not current_color.is_equal_approx(fill_color):
			image.set_pixel(pt.x, pt.y, fill_color)
			stack.append(Vector2i(pt.x + 1, pt.y))
			stack.append(Vector2i(pt.x - 1, pt.y))
			stack.append(Vector2i(pt.x, pt.y + 1))
			stack.append(Vector2i(pt.x, pt.y - 1))

## 4-Connected Flood Fill:
## Replaces connected region of old_color with new fill_color.
static func flood_fill_4(image: Image, x: int, y: int, new_color: Color, old_color: Color, max_depth: int = 10000) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return
	var stack : Array[Vector2i] = [Vector2i(x, y)]
	var visited_count : int = 0

	while not stack.is_empty() and visited_count < max_depth:
		var pt : Vector2i = stack.pop_back()
		visited_count += 1
		if pt.x < 0 or pt.x >= image.get_width() or pt.y < 0 or pt.y >= image.get_height():
			continue

		var current_color : Color = image.get_pixel(pt.x, pt.y)
		if current_color.is_equal_approx(old_color) and not current_color.is_equal_approx(new_color):
			image.set_pixel(pt.x, pt.y, new_color)
			stack.append(Vector2i(pt.x + 1, pt.y))
			stack.append(Vector2i(pt.x - 1, pt.y))
			stack.append(Vector2i(pt.x, pt.y + 1))
			stack.append(Vector2i(pt.x, pt.y - 1))
