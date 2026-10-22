## ClipAlgorithms.gd
## Implements line and polygon clipping algorithms for Computer Graphics.
##
## Line Clipping:
##   1. Cohen-Sutherland  -- region-code based, fast rejection
##   2. Liang-Barsky      -- parametric, numerically elegant
##   3. Midpoint Subdivision -- recursive bisection clipping
##
## Polygon Clipping:
##   4. Sutherland-Hodgman -- clips convex and concave-approximated polygons
##
## Usage:
##   var result := ClipAlgorithms.cohen_sutherland(p1, p2, clip_rect)
##   var clipped_poly := ClipAlgorithms.sutherland_hodgman(poly, clip_poly)

class_name ClipAlgorithms

# ---------------------------------------------------------------------------
#  2D MATRIX TRANSFORMATIONS (3x3 Homogeneous Coordinates)
#  Direct translation of Mat3 from stage3v2.cpp:
#  [ [m00, m01, m02], [m10, m11, m12], [m20, m21, m22] ]
# ---------------------------------------------------------------------------

static func mat_identity() -> Array:
	return [
		[1.0, 0.0, 0.0],
		[0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0]
	]

static func mat_translation(tx: float, ty: float) -> Array:
	return [
		[1.0, 0.0, tx],
		[0.0, 1.0, ty],
		[0.0, 0.0, 1.0]
	]

static func mat_scaling(sx: float, sy: float) -> Array:
	return [
		[sx,  0.0, 0.0],
		[0.0, sy,  0.0],
		[0.0, 0.0, 1.0]
	]

static func mat_rotation(rad: float) -> Array:
	var c := cos(rad)
	var s := sin(rad)
	return [
		[ c, -s, 0.0],
		[ s,  c, 0.0],
		[0.0, 0.0, 1.0]
	]

static func mat_multiply(A: Array, B: Array) -> Array:
	var R : Array = [
		[0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0]
	]
	for i in range(3):
		for j in range(3):
			for k in range(3):
				R[i][j] += A[i][k] * B[k][j]
	return R

static func mat_transform_point(M: Array, pt: Vector2) -> Vector2:
	var nx : float = M[0][0] * pt.x + M[0][1] * pt.y + M[0][2]
	var ny : float = M[1][0] * pt.x + M[1][1] * pt.y + M[1][2]
	return Vector2(nx, ny)

static func transform_polygon(M: Array, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mat_transform_point(M, p))
	return out

static func to_transform2d(M: Array) -> Transform2D:
	return Transform2D(
		Vector2(M[0][0], M[1][0]),
		Vector2(M[0][1], M[1][1]),
		Vector2(M[0][2], M[1][2])
	)

# ---------------------------------------------------------------------------
#  COHEN-SUTHERLAND LINE CLIPPING
# ---------------------------------------------------------------------------

## Region outcode bit masks
const CS_INSIDE : int = 0   # 0000
const CS_LEFT   : int = 1   # 0001
const CS_RIGHT  : int = 2   # 0010
const CS_BOTTOM : int = 4   # 0100
const CS_TOP    : int = 8   # 1000

## Compute the Cohen-Sutherland outcode for point (x, y) relative to [rect].
static func _cs_outcode(x: float, y: float, rect: Rect2) -> int:
	var code : int = CS_INSIDE
	var xmin : float = rect.position.x
	var xmax : float = rect.position.x + rect.size.x
	var ymin : float = rect.position.y
	var ymax : float = rect.position.y + rect.size.y
	if x < xmin:
		code |= CS_LEFT
	elif x > xmax:
		code |= CS_RIGHT
	if y < ymin:
		code |= CS_TOP
	elif y > ymax:
		code |= CS_BOTTOM
	return code

## Cohen-Sutherland Line Clip.
## Returns PackedVector2Array of 2 points if visible, empty if fully outside.
static func cohen_sutherland(p1: Vector2, p2: Vector2, rect: Rect2) -> PackedVector2Array:
	var x0 : float = p1.x;  var y0 : float = p1.y
	var x1 : float = p2.x;  var y1 : float = p2.y
	var code0 : int = _cs_outcode(x0, y0, rect)
	var code1 : int = _cs_outcode(x1, y1, rect)
	var xmin : float = rect.position.x;  var xmax : float = rect.position.x + rect.size.x
	var ymin : float = rect.position.y;  var ymax : float = rect.position.y + rect.size.y
	while true:
		if (code0 | code1) == 0:
			return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1)])
		if (code0 & code1) != 0:
			return PackedVector2Array()
		var code_out : int = code1 if code0 == CS_INSIDE else code0
		var x : float = 0.0;  var y : float = 0.0
		if (code_out & CS_BOTTOM) != 0:
			x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0);  y = ymax
		elif (code_out & CS_TOP) != 0:
			x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0);  y = ymin
		elif (code_out & CS_RIGHT) != 0:
			y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0);  x = xmax
		elif (code_out & CS_LEFT) != 0:
			y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0);  x = xmin
		if code_out == code0:
			x0 = x;  y0 = y;  code0 = _cs_outcode(x0, y0, rect)
		else:
			x1 = x;  y1 = y;  code1 = _cs_outcode(x1, y1, rect)
	return PackedVector2Array()

# ---------------------------------------------------------------------------
#  LIANG-BARSKY LINE CLIPPING
# ---------------------------------------------------------------------------

## Liang-Barsky Line Clip.
## Parametric algorithm -- more efficient for many lines.
## Returns PackedVector2Array of 2 points, or empty if outside.
static func liang_barsky(p1: Vector2, p2: Vector2, rect: Rect2) -> PackedVector2Array:
	var dx : float = p2.x - p1.x;  var dy : float = p2.y - p1.y
	var xmin : float = rect.position.x;  var xmax : float = rect.position.x + rect.size.x
	var ymin : float = rect.position.y;  var ymax : float = rect.position.y + rect.size.y
	var p : Array[float] = [-dx, dx, -dy, dy]
	var q : Array[float] = [p1.x - xmin, xmax - p1.x, p1.y - ymin, ymax - p1.y]
	var t0 : float = 0.0;  var t1 : float = 1.0
	for i in 4:
		if p[i] == 0.0:
			if q[i] < 0.0:
				return PackedVector2Array()
		elif p[i] < 0.0:
			t0 = maxf(t0, q[i] / p[i])
		else:
			t1 = minf(t1, q[i] / p[i])
	if t0 > t1:
		return PackedVector2Array()
	return PackedVector2Array([
		Vector2(p1.x + t0 * dx, p1.y + t0 * dy),
		Vector2(p1.x + t1 * dx, p1.y + t1 * dy)
	])

# ---------------------------------------------------------------------------
#  MIDPOINT SUBDIVISION LINE CLIPPING
# ---------------------------------------------------------------------------

## Midpoint Subdivision Line Clip.
## Recursively bisects the line until both halves are trivially in/out,
## or segment length drops below epsilon.
## Returns PackedVector2Array of 2 points, or empty if outside.
static func midpoint_subdivision(p1: Vector2, p2: Vector2,
		rect: Rect2, max_depth: int = 20) -> PackedVector2Array:
	return _mps_clip(p1, p2, rect, max_depth)

static func _mps_clip(p1: Vector2, p2: Vector2,
		rect: Rect2, depth: int) -> PackedVector2Array:
	var c1 : int = _cs_outcode(p1.x, p1.y, rect)
	var c2 : int = _cs_outcode(p2.x, p2.y, rect)
	if (c1 | c2) == 0:
		return PackedVector2Array([p1, p2])
	if (c1 & c2) != 0:
		return PackedVector2Array()
	if depth == 0:
		if c1 == 0:
			return PackedVector2Array([p1, (p1 + p2) * 0.5])
		elif c2 == 0:
			return PackedVector2Array([(p1 + p2) * 0.5, p2])
		return PackedVector2Array()
	var mid : Vector2 = (p1 + p2) * 0.5
	var left  := _mps_clip(p1,  mid, rect, depth - 1)
	var right := _mps_clip(mid, p2,  rect, depth - 1)
	if left.size() == 2 and right.size() == 2:
		return PackedVector2Array([left[0], right[1]])
	elif left.size() == 2:
		return left
	elif right.size() == 2:
		return right
	return PackedVector2Array()

# ---------------------------------------------------------------------------
#  SUTHERLAND-HODGMAN POLYGON CLIPPING
# ---------------------------------------------------------------------------

## Sutherland-Hodgman Polygon Clip.
## Clips [subject_poly] against the convex [clip_poly].
## Both are PackedVector2Array. Returns clipped polygon vertices (may be empty).
static func sutherland_hodgman(subject_poly: PackedVector2Array,
		clip_poly: PackedVector2Array) -> PackedVector2Array:
	var output : PackedVector2Array = subject_poly
	var n_clip : int = clip_poly.size()
	for i in n_clip:
		if output.is_empty():
			break
		var input  : PackedVector2Array = output
		output = PackedVector2Array()
		var edge_a : Vector2 = clip_poly[i]
		var edge_b : Vector2 = clip_poly[(i + 1) % n_clip]
		var n_in : int = input.size()
		for j in n_in:
			var curr : Vector2 = input[j]
			var prev : Vector2 = input[(j - 1 + n_in) % n_in]
			var curr_in : bool = _sh_inside(curr, edge_a, edge_b)
			var prev_in : bool = _sh_inside(prev, edge_a, edge_b)
			if curr_in:
				if not prev_in:
					output.append(_sh_intersect(prev, curr, edge_a, edge_b))
				output.append(curr)
			elif prev_in:
				output.append(_sh_intersect(prev, curr, edge_a, edge_b))
	return output

## Returns true if [p] is on the inside (left side) of directed edge [a -> b].
static func _sh_inside(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return (b - a).cross(p - a) >= 0.0

## Intersection of segment [p1 -> p2] with line defined by [a -> b].
static func _sh_intersect(p1: Vector2, p2: Vector2,
		a: Vector2, b: Vector2) -> Vector2:
	var d1 : float = (b - a).cross(p1 - a)
	var d2 : float = (b - a).cross(p2 - a)
	var denom : float = d1 - d2
	if abs(denom) < 1e-9:
		return p1
	var t : float = d1 / denom
	return p1 + t * (p2 - p1)

## Convenience: clip a polygon to an axis-aligned Rect2.
static func clip_polygon_to_rect(subject: PackedVector2Array,
		rect: Rect2) -> PackedVector2Array:
	var x0 : float = rect.position.x;  var y0 : float = rect.position.y
	var x1 : float = x0 + rect.size.x; var y1 : float = y0 + rect.size.y
	var clip : PackedVector2Array = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0),
		Vector2(x1, y1), Vector2(x0, y1)
	])
	return sutherland_hodgman(subject, clip)
