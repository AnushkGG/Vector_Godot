extends Node2D
## Procedural human silhouette – Cyber Ninja design with neon cyberpunk aesthetics.
## Reads state / velocity from the parent CharacterBody2D each frame.
## Collision shapes, speeds, physics, and climb IK targets/timing are NEVER modified here.

# ── Silhouette & Outlines ─────────────────────────────────────
const C          : Color = Color(0.03, 0.03, 0.08)   # deep midnight body core
const C_SHADOW   : Color = Color(0.01, 0.01, 0.04)

# ── Clothing colours (Cyber Ninja bodysuit) ───────────────────
const SHIRT_A    : Color = Color(0.06, 0.07, 0.18)   # dark bodysuit base
const SHIRT_A_HI : Color = Color(0.12, 0.14, 0.30)   # bodysuit highlight panel
const SHIRT_B    : Color = Color(0.00, 0.92, 0.98)   # neon cyan accent stripe
const SHIRT_B_SH : Color = Color(0.00, 0.60, 0.70)   # cyan stripe shadow
const PANTS      : Color = Color(0.05, 0.06, 0.16)   # dark cyberpunk leggings
const PANTS_HI   : Color = Color(0.10, 0.12, 0.28)   # leggings highlight facet
const PANTS_SH   : Color = Color(0.02, 0.03, 0.08)   # leggings shadow / crease
const BEANIE     : Color = Color(0.04, 0.04, 0.12)   # ninja hood (deep midnight)
const BEANIE_HI  : Color = Color(0.08, 0.10, 0.24)
const MASK_BG    : Color = Color(0.04, 0.04, 0.12)   # full ninja face covering
const MASK_HOLE  : Color = Color(0.00, 0.92, 0.98)   # glowing cyan visor slit
const SACK_COL   : Color = Color(0.45, 0.10, 0.95)   # data orb core (vivid purple)
const SACK_HI    : Color = Color(0.65, 0.30, 1.00)   # orb glow highlight
const SACK_SH    : Color = Color(0.28, 0.04, 0.60)   # orb shadow
const SACK_TIE   : Color = Color(0.00, 0.92, 0.98)   # orb cord / neon cable
const SKIN_TONE  : Color = Color(0.04, 0.06, 0.18)   # tactical gauntlet dark
const SKIN_HI    : Color = Color(0.08, 0.14, 0.36)
const SHOE_COL   : Color = Color(0.04, 0.05, 0.14)   # matte black boot
const SHOE_SOLE  : Color = Color(0.00, 0.92, 0.98)   # glowing neon cyan sole

# ── Anatomical body geometry (classical 7.5-head athletic build) ──
const FOOT_Y     : float = 50.0
const UPR_LEG    : float = 24.0   # longer legs (50%+ of height)
const LWR_LEG    : float = 23.0   # total leg = 47 px
const HIP_Y      : float = FOOT_Y - UPR_LEG - LWR_LEG   # = 3.0
const TORSO_H    : float = 26.0
const SHO_Y      : float = HIP_Y - TORSO_H               # = -23.0
const NECK_H     : float = 3.5
const HEAD_R     : float = 6.2    # head height ≈ 12.4 px (~1/7.5 of 92 px height)
const HEAD_Y     : float = SHO_Y - NECK_H - HEAD_R        # ≈ -32.7
const UPR_ARM    : float = 14.5
const LWR_ARM    : float = 12.5

# Shoulder & waist proportions: broad shoulder line (2x head width = 24px)
const SHO_HW     : float = 11.5   # shoulder half-width (total 23-24 px)
const HIP_HW     : float = 6.2    # waist / hip half-width (tapered V-torso)

# Arm swing
const ARM_SWING  : float = 0.72
const ELBOW_BASE : float = 1.25

# ── Animation accumulators ────────────────────────────────────
var _time           : float = 0.0
var _land_squash    : float = 0.0
var _was_floor      : bool  = true
var _jump_time      : float = 0.0
var _is_air         : bool  = false
var _slide_blend    : float = 0.0
var _climb_dist     : float = 0.0
var _prev_climb_y   : float = -999999.0
var _bag_lag_offset : Vector2 = Vector2.ZERO
var _idle_time      : float = 0.0

# ──────────────────────────────────────────────────────────────

func _ready() -> void:
	var p := get_parent()
	if p and "CHARACTER_SCALE" in p:
		var s : float = float(p.CHARACTER_SCALE)
		scale = Vector2(s, s)
		position.y = FOOT_Y * (1.0 - s)

func _process(delta: float) -> void:
	var p := get_parent()
	if not p:
		return
	var st : String = p.get("state") if p.get("state") else "run"

	if st == "run":
		var spd : float = p.get("run_speed") if p.get("run_speed") else 500.0
		_time += delta * (spd / 500.0) * 8.0
		_prev_climb_y = -999999.0
		_climb_dist = 0.0
	elif st == "jump" or st == "fall":
		_time += delta * 4.0
		_prev_climb_y = -999999.0
		_climb_dist = 0.0
	elif st == "slide":
		_time += delta * 10.0
		_prev_climb_y = -999999.0
		_climb_dist = 0.0
	elif st == "stun":
		_time = 0.0
		_prev_climb_y = -999999.0
		_climb_dist = 0.0
	elif st == "climb":
		var cur_y : float = p.global_position.y
		if _prev_climb_y > -900000.0:
			var dy : float = _prev_climb_y - cur_y
			_climb_dist += absf(dy)
		_prev_climb_y = cur_y
	else:
		_idle_time += delta

	var on_fl : bool = p.is_on_floor() if p.has_method("is_on_floor") else true
	if not on_fl and _was_floor:
		_jump_time = 0.0
		_is_air = true
	elif on_fl and not _was_floor:
		_land_squash = 1.0
		_is_air = false
		_jump_time = 0.0
	_was_floor = on_fl

	if _is_air:
		_jump_time += delta
	_land_squash = maxf(0.0, _land_squash - delta / 0.12)

	if st == "slide":
		_slide_blend = clampf(_slide_blend + delta * 12.0, 0.0, 1.0)
	else:
		_slide_blend = 0.0

	# ── Secondary motion: bag bounce with 1-2 frame inertia lag ──
	var target_bag_offset := Vector2.ZERO
	if st == "run":
		target_bag_offset.y = sin(_time * 2.0 - 0.45) * 2.2
		target_bag_offset.x = cos(_time - 0.25) * 1.2
	elif st == "jump" or st == "fall":
		var vy : float = p.velocity.y if "velocity" in p else 0.0
		target_bag_offset.y = clampf(-vy * 0.015, -3.5, 3.5)
	elif st == "climb":
		target_bag_offset.y = sin(_climb_dist * 0.15) * 1.5
	elif st == "stun":
		target_bag_offset = Vector2(-2.0, 3.0)
	else:
		target_bag_offset.y = sin(_idle_time * 2.2) * 0.6

	_bag_lag_offset = _bag_lag_offset.lerp(target_bag_offset, clampf(delta * 22.0, 0.0, 1.0))

	queue_redraw()

func _draw() -> void:
	var p := get_parent()
	if not p:
		return
	var st : String = p.get("state") if p.get("state") else "run"

	# =========================================================================
	# 2D MATRIX TRANSFORMATIONS (3x3 Homogeneous Coordinates from stage3v2.cpp)
	# =========================================================================
	var pivot_y : float = HIP_Y  # Center of mass pivot

	# 1. SCALING: Dynamic Squash & Stretch from jump air-state and landing impact
	var sx : float = 1.0
	var sy : float = 1.0
	if st == "jump" or st == "fall":
		# Air elongation: stretch vertically by 15%, thin horizontally by 8% (as in stage3v2.cpp)
		sx = 0.92
		sy = 1.15
	elif _land_squash > 0.01:
		# Landing compression: squash vertically, widen horizontally upon impact
		sx = 1.0 + _land_squash * 0.28
		sy = 1.0 - _land_squash * 0.22

	# 2. ROTATION: Body tilt
	var rot_angle : float = 0.0
	if st == "slide":
		rot_angle = -0.15

	# Parkour Backflip 360-degree rotation and athletic tuck
	var is_flip : bool = ("is_backflipping" in p) and p.is_backflipping
	if is_flip:
		rot_angle += p.backflip_rot
		var tuck : float = sin(p.backflip_progress * PI)
		sx *= (1.0 - tuck * 0.28)
		sy *= (1.0 - tuck * 0.25)

	# Construct 3x3 Matrices: M = T(pivot) * (S * R) * T(-pivot)
	var T1 := ClipAlgorithms.mat_translation(0.0, pivot_y)
	var S  := ClipAlgorithms.mat_scaling(sx, sy)
	var R  := ClipAlgorithms.mat_rotation(rot_angle)
	var T2 := ClipAlgorithms.mat_translation(0.0, -pivot_y)

	var M := ClipAlgorithms.mat_multiply(
		T1,
		ClipAlgorithms.mat_multiply(
			ClipAlgorithms.mat_multiply(S, R),
			T2
		)
	)

	# Apply the 3x3 Homogeneous Transformation Matrix to all player drawing
	draw_set_transform_matrix(ClipAlgorithms.to_transform2d(M))

	# Dual neon parkour motion trail ribbon during backflip
	if is_flip:
		var prog : float = p.backflip_progress
		var trail_alpha : float = sin(prog * PI) * 0.85
		var arc_col_cyan := Color(0.00, 0.92, 1.00, trail_alpha)
		var arc_col_mag  := Color(0.70, 0.15, 1.00, trail_alpha * 0.85)
		draw_arc(Vector2(0.0, pivot_y), 36.0, 0.0, -TAU * prog * 0.7, 16, arc_col_cyan, 2.5)
		draw_arc(Vector2(0.0, pivot_y), 24.0, 0.3, -TAU * prog * 0.6 + 0.3, 14, arc_col_mag, 2.0)

	match st:
		"run":
			if is_flip:
				var vy : float = p.velocity.y if "velocity" in p else -300.0
				_draw_air(vy)
			else:
				_draw_run()
		"jump", "fall":
			var vy : float = p.velocity.y if "velocity" in p else 0.0
			_draw_air(vy)
		"slide":
			_draw_slide()
		"stun":
			_draw_stun()
		"climb":
			_draw_climb()
		_:
			_draw_run()

	# Reset transform matrix
	draw_set_transform_matrix(Transform2D.IDENTITY)

# ── Math / Interpolation Helper ───────────────────────────────
func _smooth(val: float) -> float:
	var v := clampf(val, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)

func _tip(origin: Vector2, angle: float, length: float) -> Vector2:
	return origin + Vector2(cos(angle), sin(angle)) * length

# ── CONTINUOUS TAPERED LIMB GENERATOR (Catmull-Rom Spline & Fold Pinch) ──
# Constructs ONE unified smoothed polygon along root->joint->tip.
# Pinches inner fold by ~30% and bulges outer fold with soft crease line when bend > 90°.
# Eliminates all joint circles, dividing discs, gaps, and rigid segments.
func _draw_continuous_limb(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	w0: float,
	wb1: float,
	w1: float,
	wb2: float,
	w2: float,
	col_base: Color,
	col_hi: Color,
	col_crease: Color,
	is_leg: bool,
	is_far: bool,
	flex: float = 0.0
) -> void:
	var v1 := p1 - p0
	var v2 := p2 - p1
	var L1 := v1.length()
	var L2 := v2.length()
	if L1 < 0.5 or L2 < 0.5:
		return
	var u1 := v1 / L1
	var u2 := v2 / L2

	# Bend angle calculation (flexion from straight, 0 = straight, PI = folded)
	var dot_val  := clampf(u1.dot(u2), -1.0, 1.0)
	var bend_ang := acos(dot_val)

	# Fold shape intensity when bend angle > 90° (1.5708 rad)
	var fold_t : float = 0.0
	if bend_ang > 1.5708:
		var max_bend : float = deg_to_rad(140.0) if is_leg else deg_to_rad(150.0)
		fold_t = clampf((bend_ang - 1.5708) / (max_bend - 1.5708), 0.0, 1.0)
		fold_t = _smooth(fold_t)

	# Cross product determines inner vs outer side of bend
	var cross_val : float = u1.x * u2.y - u1.y * u2.x

	# Catmull-Rom tangents at joint points
	var t0 := p1 - p0
	var t1 := (p2 - p0) * 0.5
	var t2 := p2 - p1

	# Sample centerline curve and calculate offset profiles
	var samples : int = 16
	var pts_left  := PackedVector2Array()
	var pts_right := PackedVector2Array()
	var pts_mid   := PackedVector2Array()

	var fold_inner_mid  := Vector2.ZERO
	var fold_inner_prev := Vector2.ZERO
	var fold_inner_next := Vector2.ZERO
	var fold_crease_apex := Vector2.ZERO

	for i in range(samples + 1):
		var s : float = float(i) / float(samples)
		var c : Vector2
		var c_prime : Vector2

		if s <= 0.5:
			var u      : float = s / 0.5
			var u2_val : float = u * u
			var u3_val : float = u2_val * u
			var h00 := 2.0 * u3_val - 3.0 * u2_val + 1.0
			var h10 := u3_val - 2.0 * u2_val + u
			var h01 := -2.0 * u3_val + 3.0 * u2_val
			var h11 := u3_val - u2_val
			c = h00 * p0 + h10 * t0 + h01 * p1 + h11 * t1

			var dh00 := 6.0 * u2_val - 6.0 * u
			var dh10 := 3.0 * u2_val - 4.0 * u + 1.0
			var dh01 := -6.0 * u2_val + 6.0 * u
			var dh11 := 3.0 * u2_val - 2.0 * u
			c_prime = 2.0 * (dh00 * p0 + dh10 * t0 + dh01 * p1 + dh11 * t1)
		else:
			var u      : float = (s - 0.5) / 0.5
			var u2_val : float = u * u
			var u3_val : float = u2_val * u
			var h00 := 2.0 * u3_val - 3.0 * u2_val + 1.0
			var h10 := u3_val - 2.0 * u2_val + u
			var h01 := -2.0 * u3_val + 3.0 * u2_val
			var h11 := u3_val - u2_val
			c = h00 * p1 + h10 * t1 + h01 * p2 + h11 * t2

			var dh00 := 6.0 * u2_val - 6.0 * u
			var dh10 := 3.0 * u2_val - 4.0 * u + 1.0
			var dh01 := -6.0 * u2_val + 6.0 * u
			var dh11 := 3.0 * u2_val - 2.0 * u
			c_prime = 2.0 * (dh00 * p1 + dh10 * t1 + dh01 * p2 + dh11 * t2)

		var tang : Vector2 = c_prime.normalized() if c_prime.length_squared() > 0.0001 else (p2 - p0).normalized()
		var norm : Vector2 = Vector2(-tang.y, tang.x)

		# Piecewise width profile
		var w : float
		if s <= 0.25:
			w = lerpf(w0, wb1, _smooth(s / 0.25))
		elif s <= 0.50:
			w = lerpf(wb1, w1, _smooth((s - 0.25) / 0.25))
		elif s <= 0.72:
			w = lerpf(w1, wb2, _smooth((s - 0.50) / 0.22))
		else:
			w = lerpf(wb2, w2, _smooth((s - 0.72) / 0.28))

		# Fold compression around joint
		var dist_to_joint : float = absf(s - 0.50) / 0.22
		var fold_falloff  : float = cos(clampf(dist_to_joint, 0.0, 1.0) * (PI * 0.5))
		var scale_inner   : float = 1.0 - 0.30 * fold_t * fold_falloff
		var scale_outer   : float = 1.0 + 0.15 * fold_t * fold_falloff

		var off_left  : float = (w * 0.5) * (scale_inner if cross_val > 0.0 else scale_outer)
		var off_right : float = (w * 0.5) * (scale_outer if cross_val > 0.0 else scale_inner)

		var pt_l := c + norm * off_left
		var pt_r := c - norm * off_right
		var pt_m := c + norm * (off_left * 0.18)

		pts_left.append(pt_l)
		pts_right.append(pt_r)
		pts_mid.append(pt_m)

		if i == 7:
			fold_inner_prev = pt_l if cross_val > 0.0 else pt_r
		elif i == 8:
			fold_inner_mid = pt_l if cross_val > 0.0 else pt_r
			var norm_inner := norm if cross_val > 0.0 else -norm
			fold_crease_apex = c + norm_inner * (w * 0.14 * fold_t)
		elif i == 9:
			fold_inner_next = pt_l if cross_val > 0.0 else pt_r

	# Seamless rounded cap at limb root (shoulder or hip)
	var root_tang := (p1 - p0).normalized()
	var root_norm := Vector2(-root_tang.y, root_tang.x)
	var cap_pts := PackedVector2Array()
	var cap_steps : int = 5
	for k in range(cap_steps + 1):
		var ang := -PI * 0.5 + float(k) * (PI / float(cap_steps))
		var p_cap := p0 - root_tang * (w0 * 0.5 * cos(ang)) + root_norm * (w0 * 0.5 * sin(ang))
		cap_pts.append(p_cap)

	# 1. Main Continuous Limb Polygon (single fill color for garment/skin)
	var full_poly := PackedVector2Array()
	full_poly.append_array(cap_pts)
	full_poly.append_array(pts_left)
	var r_reversed := pts_right.duplicate()
	r_reversed.reverse()
	full_poly.append_array(r_reversed)
	draw_colored_polygon(full_poly, col_base)

	# 2. Continuous 2-Tone Highlight Facet (follows smoothed limb shape)
	var hi_poly := PackedVector2Array()
	hi_poly.append_array(pts_left)
	var m_reversed := pts_mid.duplicate()
	m_reversed.reverse()
	hi_poly.append_array(m_reversed)
	draw_colored_polygon(hi_poly, col_hi)

	# 3. Soft Fold Crease Line on Inner Fold (when bend > 90°)
	if fold_t > 0.08:
		var crease_poly := PackedVector2Array([
			fold_inner_prev, fold_inner_mid, fold_inner_next, fold_crease_apex
		])
		draw_colored_polygon(crease_poly, col_crease)
		draw_line(fold_inner_mid, fold_crease_apex, col_crease.darkened(0.25), 1.2, false)

# ── RUN (Real 4-Phase Gait: Contact, Down, Passing, Up) ───────
func _draw_run() -> void:
	var t : float = _time

	# 1. Torso Lean (about 10 degrees = 0.1745 rad) + landing absorption
	var lean : float = 0.1745
	var sq   : float = 0.0
	if _land_squash > 0.0:
		var st_sq : float = clampf(_land_squash, 0.0, 1.0)
		sq = st_sq * st_sq * (3.0 - 2.0 * st_sq)
		lean += 0.14 * sq

	# Idle breathing bob when stationary
	var p := get_parent()
	var spd : float = absf(p.velocity.x) if (p and "velocity" in p) else 500.0
	var is_idle : bool = spd < 10.0

	# 2. Vertical Body Bob of about 2px (dips on 'down' phase twice per cycle)
	var bob : float = sin(t * 2.0 - PI * 0.5) * 2.0
	if is_idle:
		bob = sin(_idle_time * 2.5) * 0.8
		lean = 0.04

	# 3. Transverse Hip Rotation (hips rotate slightly as legs swing)
	var hip_rot : float = sin(t) * 0.08
	var lead_hip_offset : Vector2 = Vector2(hip_rot * 22.0, 0.0)

	var hip_base : Vector2 = Vector2(0.0, HIP_Y + bob + 3.8 * sq)
	var sho_base : Vector2 = _tip(hip_base, -PI * 0.5 + lean, TORSO_H)
	var neck     : Vector2 = _tip(sho_base, -PI * 0.5 + lean, NECK_H)
	var hd       : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	# 4. Leg Kinematics (Contact, Down, Passing, Up)
	var leg_data := []
	for i : int in 2:
		var phase : float = t if i == 0 else t + PI
		var w : float = fposmod(phase, TAU) / TAU   # normalized stride progress in [0, 1)
		var thigh_ang : float
		var knee_bend : float
		var foot_tilt : float
		var push_flex : float = 0.0

		if w < 0.50:
			# ── STANCE PHASE (Contact -> Down -> Push-off) ──
			var s : float = w / 0.50
			thigh_ang = (PI * 0.5) - lerpf(0.44, -0.40, _smooth(s))
			if s < 0.25:
				# Contact: heel strikes first, knee slightly flexed
				var sub := s / 0.25
				knee_bend = lerpf(deg_to_rad(22.0), deg_to_rad(38.0), _smooth(sub))
				foot_tilt = lerpf(-0.28, -0.05, _smooth(sub))
			elif s < 0.65:
				# Down / Weight-bearing: knee flexes to absorb weight, foot rolls flat
				var sub := (s - 0.25) / 0.40
				knee_bend = lerpf(deg_to_rad(38.0), deg_to_rad(48.0), sin(sub * PI))
				foot_tilt = 0.0
			else:
				# Push-off / Extension: pushes off toe, knee extends
				var sub := (s - 0.65) / 0.35
				knee_bend = lerpf(deg_to_rad(38.0), deg_to_rad(18.0), _smooth(sub))
				foot_tilt = lerpf(0.0, 0.50, _smooth(sub))
				push_flex = sin(sub * PI)
		else:
			# ── SWING / RECOVERY PHASE (Passing -> Up / Butt Kick -> Pre-contact) ──
			var r : float = (w - 0.50) / 0.50
			if r < 0.45:
				# Up: knee folds up to about 110 degrees, heel kicks toward butt
				var sub := r / 0.45
				knee_bend = lerpf(deg_to_rad(24.0), deg_to_rad(110.0), _smooth(sub))
				thigh_ang = (PI * 0.5) - lerpf(-0.40, 0.12, _smooth(sub))
				foot_tilt = 0.35
			else:
				# Passing forward & reach: knee unfolds forward, prepares for heel strike
				var sub := (r - 0.45) / 0.55
				knee_bend = lerpf(deg_to_rad(110.0), deg_to_rad(22.0), _smooth(sub))
				thigh_ang = (PI * 0.5) - lerpf(0.12, 0.44, _smooth(sub))
				foot_tilt = lerpf(0.35, -0.28, _smooth(sub))

		if sq > 0.0:
			knee_bend += 0.55 * sq

		leg_data.append({
			"thigh": thigh_ang,
			"knee": clampf(knee_bend, deg_to_rad(15.0), deg_to_rad(140.0)),
			"tilt": foot_tilt,
			"flex": push_flex
		})

	# 5. Arm Kinematics (Opposite legs, elbow bent about 90°, swinging in an arc)
	var asw : float = cos(t) * ARM_SWING
	var base_arm : float = PI * 0.5 + lean
	var a_near   : float = base_arm - asw
	var a_far    : float = base_arm + asw

	# 3D arc lateral excursion (swinging in an arc, not a pendulum)
	var arc_near : float = sin(t) * 3.0
	var arc_far  : float = -sin(t) * 3.0

	if sq > 0.0:
		a_near = lerpf(a_near, PI * 0.5 + lean - 0.45, sq * 0.75)
		a_far  = lerpf(a_far,  PI * 0.5 + lean - 0.35, sq * 0.75)

	var torso_twist : float = -asw * 0.04

	# 1. Far leg (trailing leg index 1)
	var hip_far := hip_base - lead_hip_offset
	_draw_anatomical_leg(hip_far, leg_data[1]["thigh"], leg_data[1]["knee"], true, leg_data[1]["flex"], leg_data[1]["tilt"])
	# 2. Far arm
	var sho_far := sho_base - lead_hip_offset * 0.5
	_draw_anatomical_arm(sho_far, a_far, true, false, arc_far)
	# 3. Torso, neck, loot sack
	_draw_torso_anatomical(hip_base, sho_base, lean, torso_twist)
	_draw_neck(sho_base, neck)
	# 4. Near leg (lead leg index 0)
	var hip_near := hip_base + lead_hip_offset
	_draw_anatomical_leg(hip_near, leg_data[0]["thigh"], leg_data[0]["knee"], false, leg_data[0]["flex"], leg_data[0]["tilt"])
	# 5. Near arm
	var sho_near := sho_base + lead_hip_offset * 0.5
	_draw_anatomical_arm(sho_near, a_near, false, false, arc_near)
	# 6. Head (stays level: counter-rotates by negative of torso lean)
	_draw_head_anatomical(hd, -lean)

# ── AIRBORNE (Anticipation Crouch, Takeoff Extension, Mid-Air Tuck, Landing Absorb) ──
func _draw_air(vel_y: float) -> void:
	var hip_y       : float = 0.0
	var lean        : float = 0.1745
	var lead_thigh  : float = 0.0
	var lead_knee   : float = 0.0
	var trail_thigh : float = 0.0
	var trail_knee  : float = 0.0
	var arm_lead    : float = 0.0
	var arm_trail   : float = 0.0

	# 1. Mid-air tuck around apex (velocity.y around 0): knees about 90°, one leg leading, arms balanced
	if vel_y < 0.0:
		# Ascent towards apex: legs transition from takeoff extension to tuck
		var raw_u : float = clampf((vel_y - (-280.0)) / 280.0, 0.0, 1.0)
		var u     : float = _smooth(raw_u)
		hip_y       = lerpf(-3.0, -5.5, u)
		lean        = lerpf(0.24, 0.18, u)
		# Lead leg tucks to ~90°
		lead_thigh  = lerpf(0.35, 0.14, u)
		lead_knee   = lerpf(deg_to_rad(45.0), deg_to_rad(92.0), u)
		# Trailing leg tucks under body
		trail_thigh = lerpf(PI * 0.5 + 0.35, 0.44, u)
		trail_knee  = lerpf(deg_to_rad(30.0), deg_to_rad(88.0), u)
		# Arms balanced
		arm_lead    = lerpf(PI * 0.5 + lean - 0.90, PI * 0.5 + lean - 0.60, u)
		arm_trail   = lerpf(PI * 0.5 + lean + 0.65, PI * 0.5 + lean - 0.25, u)
	else:
		# Descent from apex: preparing for landing extension
		var raw_u : float = clampf(vel_y / 280.0, 0.0, 1.0)
		var u     : float = _smooth(raw_u)
		hip_y       = lerpf(-5.5, -1.0, u)
		lean        = lerpf(0.18, 0.16, u)
		lead_thigh  = lerpf(0.14, PI * 0.5 - 0.26, u)
		lead_knee   = lerpf(deg_to_rad(92.0), deg_to_rad(35.0), u)
		trail_thigh = lerpf(0.44, PI * 0.5 + 0.08, u)
		trail_knee  = lerpf(deg_to_rad(88.0), deg_to_rad(32.0), u)
		arm_lead    = lerpf(PI * 0.5 + lean - 0.60, PI * 0.5 + lean - 0.40, u)
		arm_trail   = lerpf(PI * 0.5 + lean - 0.25, PI * 0.5 + lean + 0.35, u)

	# 2. Takeoff Initiation: Anticipation Crouch (first 0.04s) & Takeoff Extension (0.04 - 0.08s)
	if _jump_time < 0.08:
		var raw_to : float = clampf(_jump_time / 0.08, 0.0, 1.0)
		var w_to   : float = 1.0 - _smooth(raw_to)
		var to_hip_y       : float = 0.0
		var to_lean        : float = 0.1745
		var to_lead_thigh  : float = PI * 0.5
		var to_lead_knee   : float = deg_to_rad(100.0)   # knees about 100°
		var to_trail_thigh : float = PI * 0.5
		var to_trail_knee  : float = deg_to_rad(100.0)
		var to_arm_lead    : float = PI * 0.5 + lean + 0.40   # arms swung back
		var to_arm_trail   : float = PI * 0.5 + lean + 0.40

		if raw_to >= 0.5:
			# Takeoff extension: legs straight, arms swing up
			var sub : float = (raw_to - 0.5) / 0.5
			var s_sub := _smooth(sub)
			to_hip_y       = lerpf(4.5, -3.5, s_sub)
			to_lean        = lerpf(0.30, 0.18, s_sub)
			to_lead_thigh  = lerpf(PI * 0.5, PI * 0.5 + 0.28, s_sub)
			to_lead_knee   = lerpf(deg_to_rad(100.0), deg_to_rad(18.0), s_sub)
			to_trail_thigh = lerpf(PI * 0.5, PI * 0.5 + 0.32, s_sub)
			to_trail_knee  = lerpf(deg_to_rad(100.0), deg_to_rad(18.0), s_sub)
			to_arm_lead    = lerpf(PI * 0.5 + to_lean + 0.40, PI * 0.5 + to_lean - 0.85, s_sub)
			to_arm_trail   = lerpf(PI * 0.5 + to_lean + 0.40, PI * 0.5 + to_lean - 0.65, s_sub)

		hip_y       = lerpf(hip_y, to_hip_y, w_to)
		lean        = lerpf(lean, to_lean, w_to)
		lead_thigh  = lerpf(lead_thigh, to_lead_thigh, w_to)
		lead_knee   = lerpf(lead_knee, to_lead_knee, w_to)
		trail_thigh = lerpf(trail_thigh, to_trail_thigh, w_to)
		trail_knee  = lerpf(trail_knee, to_trail_knee, w_to)
		arm_lead    = lerpf(arm_lead, to_arm_lead, w_to)
		arm_trail   = lerpf(arm_trail, to_arm_trail, w_to)

	var hip : Vector2 = Vector2(0.0, HIP_Y + hip_y)
	var sho : Vector2 = _tip(hip, -PI * 0.5 + lean, TORSO_H)
	var neck: Vector2 = _tip(sho, -PI * 0.5 + lean, NECK_H)
	var hd  : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	_draw_anatomical_leg(hip, trail_thigh, trail_knee, true, 0.2)
	_draw_anatomical_arm(sho, arm_trail, true, false)
	_draw_torso_anatomical(hip, sho, lean, 0.0)
	_draw_neck(sho, neck)
	_draw_anatomical_leg(hip, lead_thigh, lead_knee, false, 0.1)
	_draw_anatomical_arm(sho, arm_lead, false, false)
	_draw_head_anatomical(hd, -lean)

# ── SLIDE ─────────────────────────────────────────────────────
func _draw_slide() -> void:
	var lean    : float   = -0.55
	var pivot_y : float   = HIP_Y + lerpf(4.0, 12.0, _slide_blend)
	var pivot   : Vector2 = Vector2(0.0, pivot_y)
	var sho     : Vector2 = _tip(pivot, lean - PI * 0.5, TORSO_H)
	var neck    : Vector2 = sho + Vector2(-5.0, -3.0)
	var hd      : Vector2 = neck + Vector2(-4.0, -6.0)

	var knee_b : Vector2 = _tip(pivot, PI * 0.5 + 0.1, UPR_LEG)
	var foot_b : Vector2 = _tip(knee_b, PI * 0.5, LWR_LEG)
	foot_b.y = minf(foot_b.y, FOOT_Y)

	var knee_f : Vector2 = pivot + Vector2(10.0, 8.0)
	var foot_f : Vector2 = knee_f + Vector2(8.0, 4.0)
	foot_f.y = minf(foot_f.y, FOOT_Y)

	# 1. Back leg (tucked under)
	_draw_leg_points(pivot, knee_b, foot_b, true, 0.3)
	# 2. Far arm tucked
	var arm_far_elbow := sho + Vector2(-6.0, 5.0)
	var arm_far_hand  := arm_far_elbow + Vector2(7.0, 2.0)
	_draw_arm_points(sho + Vector2(-2.0, 0.0), arm_far_elbow, arm_far_hand, true, true)
	# 3. Torso
	_draw_torso_anatomical(pivot, sho, lean, 0.0)
	_draw_neck(sho, neck)
	# 4. Front leg (extended)
	_draw_leg_points(pivot, knee_f, foot_f, false, 0.4)
	# 5. Near arm tucked
	var arm_near_elbow := sho + Vector2(4.0, 6.0)
	var arm_near_hand  := arm_near_elbow + Vector2(6.0, 1.0)
	_draw_arm_points(sho + Vector2(2.0, 0.0), arm_near_elbow, arm_near_hand, false, true)
	# 6. Head watching ahead
	_draw_head_anatomical(hd, 0.25)

# ── STUN ──────────────────────────────────────────────────────
func _draw_stun() -> void:
	var lean : float   = -0.20
	var hip  : Vector2 = Vector2(0.0, HIP_Y + 4.0)
	var sho  : Vector2 = _tip(hip, lean - PI * 0.5, TORSO_H)
	var neck : Vector2 = _tip(sho, lean - PI * 0.5, NECK_H)
	var hd   : Vector2 = _tip(neck, lean - PI * 0.5 - 0.15, HEAD_R)

	_draw_anatomical_leg(hip, PI * 0.5 + lean + 0.20, deg_to_rad(28.0), true, 0.0)
	_draw_anatomical_arm(sho, PI * 0.5 + lean - 0.45, true, false)
	_draw_torso_anatomical(hip, sho, lean, 0.0)
	_draw_neck(sho, neck)
	_draw_anatomical_leg(hip, PI * 0.5 + lean - 0.15, deg_to_rad(20.0), false, 0.0)
	_draw_anatomical_arm(sho, PI * 0.5 + lean + 0.60, false, false)
	_draw_head_anatomical(hd, -0.30)

# ── 2-Bone Leg IK Solver (hip -> knee -> foot) ────────────────
func _solve_leg_ik(hip_pt: Vector2, target_foot: Vector2, is_far: bool) -> Dictionary:
	var L1 : float = UPR_LEG   # 24.0
	var L2 : float = LWR_LEG   # 23.0

	var diff : Vector2 = target_foot - hip_pt
	var d : float = diff.length()

	# Clamp target distance so knee angle stays within human range [15°, 140°]
	var d_min : float = 13.5
	var d_max : float = 45.0
	d = clampf(d, d_min, d_max)

	var dir : Vector2 = diff.normalized() if diff.length_squared() > 0.001 else Vector2.DOWN

	# Law of cosines for interior knee angle beta
	var cos_beta : float = clampf((L1 * L1 + L2 * L2 - d * d) / (2.0 * L1 * L2), -1.0, 1.0)
	var beta : float = acos(cos_beta)
	# Interior angle beta clamped to [40°, 165°] corresponds to knee bend [15°, 140°]
	beta = clampf(beta, deg_to_rad(40.0), deg_to_rad(165.0))

	# Distance from clamped beta
	d = sqrt(maxf(0.1, L1 * L1 + L2 * L2 - 2.0 * L1 * L2 * cos(beta)))

	# Angle alpha at hip
	var cos_alpha : float = clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * maxf(d, 0.001)), -1.0, 1.0)
	var alpha : float = acos(cos_alpha)

	# The knee always bends forward (+x) toward the tower
	var perp := Vector2(dir.y, -dir.x)
	if perp.x < 0.0:
		perp = -perp

	var lat_x : float = -1.2 if is_far else 1.2
	var knee_pos : Vector2 = hip_pt + dir * (L1 * cos(alpha)) + perp * (L1 * sin(alpha))
	knee_pos.x += lat_x * 0.5

	var actual_foot : Vector2 = hip_pt + dir * d
	actual_foot.x += lat_x * 0.5

	return {
		"knee": knee_pos,
		"foot": actual_foot,
		"knee_angle": beta
	}

# ── CLIMB (Continuous Limbs, Soft Compression & Fold Creases) ──
func _draw_climb() -> void:
	var p := get_parent()
	var is_mantle : bool = p.get("is_mantling") if p else false
	if is_mantle:
		var prog : float = float(p.get("mantle_progress")) if p else 0.5
		_draw_mantle(prog)
		return

	# Drive cycle from vertical distance climbed (one full cycle per 90px)
	var cycle_norm : float = fmod(_climb_dist, 90.0) / 90.0
	var is_side_b  : bool  = cycle_norm >= 0.5
	var u          : float = (cycle_norm - 0.5) / 0.5 if is_side_b else cycle_norm / 0.5

	# Bob on pull-up (u in [0.20, 0.40]) and settle (u in [0.40, 0.60])
	var bob : float = 0.0
	if u >= 0.20 and u < 0.40:
		bob = lerpf(-1.0, 2.2, _smooth((u - 0.20) / 0.20))
	elif u >= 0.40 and u < 0.60:
		bob = lerpf(2.2, 0.0, _smooth((u - 0.40) / 0.20))

	# Hip shifts slightly toward the planted standing leg
	var standing_side : float = 1.0 if not is_side_b else -1.0
	var hip_shift_x   : float = standing_side * 1.2
	var sway_x        : float = 0.0
	var sway_lean     : float = 0.0

	# Hold phase (u in [0.80, 1.00]): pause about 0.1s with all 4 limbs gripping + slight body sway
	if u >= 0.80:
		var h_prog := _smooth((u - 0.80) / 0.20)
		hip_shift_x = lerpf(standing_side * 1.2, -standing_side * 1.2, h_prog)
		var sway_curve := sin(h_prog * PI)
		sway_x    = sway_curve * 1.5 * standing_side
		sway_lean = sway_curve * 0.03 * standing_side

	var lean : float = 0.08 + sway_lean
	var hip  : Vector2 = Vector2(hip_shift_x + sway_x, HIP_Y + bob)
	var sho  : Vector2 = _tip(hip, -PI * 0.5 + lean, TORSO_H)
	var neck : Vector2 = _tip(sho, -PI * 0.5 + lean, NECK_H)
	var hd   : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	# ── Arms (alternate opposite hand and foot) ──
	var active_arm_t : float = 0.0
	if u < 0.20:
		active_arm_t = _smooth(u / 0.20)
	elif u < 0.40:
		active_arm_t = 1.0 - _smooth((u - 0.20) / 0.20)
	else:
		active_arm_t = 0.0

	var r_arm_t : float = active_arm_t if not is_side_b else 0.0
	var l_arm_t : float = 0.0 if not is_side_b else active_arm_t

	var torso_reach_twist : float = (r_arm_t - l_arm_t) * 0.05

	# ── Legs (both legs work, 2-bone IK targeting tower rungs) ──
	var rung_low  := Vector2(10.0, 36.5)
	var rung_high := Vector2(10.5, 23.5)
	var lift_peak := Vector2(12.5, 18.0)

	var standing_foot_target := hip + rung_low
	if u < 0.40:
		standing_foot_target = hip + rung_high.lerp(rung_low, _smooth(u / 0.40))

	var moving_foot_target : Vector2
	if u < 0.40:
		moving_foot_target = hip + rung_low
	elif u < 0.65:
		var p_lift := _smooth((u - 0.40) / 0.25)
		moving_foot_target = hip + rung_low.lerp(lift_peak, p_lift)
	elif u < 0.80:
		var p_plant := _smooth((u - 0.65) / 0.15)
		moving_foot_target = hip + lift_peak.lerp(rung_high, p_plant)
	else:
		moving_foot_target = hip + rung_high

	var r_foot_target := standing_foot_target if not is_side_b else moving_foot_target
	var l_foot_target := moving_foot_target if not is_side_b else standing_foot_target

	var r_ik := _solve_leg_ik(hip + Vector2(1.5, 0.0), r_foot_target, false)
	var l_ik := _solve_leg_ik(hip + Vector2(-1.5, 0.0), l_foot_target, true)

	# 1. Far limbs (left side) drawn behind torso
	_draw_leg_points(hip + Vector2(-1.5, 0.0), l_ik["knee"], l_ik["foot"], true, 0.2)
	_draw_climb_arm(sho + Vector2(-2.0, 0.0), l_arm_t, true)

	# 2. Torso, neck, head
	_draw_torso_anatomical(hip, sho, lean, torso_reach_twist)
	_draw_neck(sho, neck)
	_draw_head_anatomical(hd, -lean * 0.5)

	# 3. Near limbs (right side) drawn in front of torso
	_draw_leg_points(hip + Vector2(1.5, 0.0), r_ik["knee"], r_ik["foot"], false, 0.2)
	_draw_climb_arm(sho + Vector2(2.0, 0.0), r_arm_t, false)

func _draw_climb_arm(base_sho: Vector2, reach_t: float, is_far: bool) -> void:
	# Pulling elbow folds with inner crease (elbow bend ~90°), reaching arm nearly straight (~20° natural bend)
	var reach_hand  := base_sho + Vector2(9.5, -23.5)
	var reach_elbow := base_sho + Vector2(6.5, -12.0)
	var pull_hand   := base_sho + Vector2(12.0, -2.5)
	var pull_elbow  := base_sho + Vector2(2.5, 7.5)

	var hand  : Vector2 = pull_hand.lerp(reach_hand, reach_t)
	var elbow : Vector2 = pull_elbow.lerp(reach_elbow, reach_t)

	# Shoulders rise on the pull
	var sho_pt := base_sho + Vector2(0.0, -reach_t * 2.0)
	_draw_arm_points(sho_pt, elbow, hand, is_far, true, reach_t)

func _draw_mantle(prog: float) -> void:
	var sp : float = _smooth(prog)
	var lean : float = lerpf(0.18, 0.38, sp)
	var hip_y : float = HIP_Y - lerpf(4.0, 14.0, sp)
	var hip : Vector2 = Vector2(lerpf(0.0, 6.0, sp), hip_y)
	var sho : Vector2 = _tip(hip, -PI * 0.5 + lean, TORSO_H)
	var neck: Vector2 = _tip(sho, -PI * 0.5 + lean, NECK_H)
	var hd  : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	# Trailing leg (left leg): hanging / pushing down off brace
	var trail_target := hip + Vector2(4.0, 40.0)
	var trail_ik := _solve_leg_ik(hip + Vector2(-1.5, 0.0), trail_target, true)
	_draw_leg_points(hip + Vector2(-1.5, 0.0), trail_ik["knee"], trail_ik["foot"], true, 0.3)

	# Leading leg (right leg): ONE KNEE UP on the ledge edge
	var lead_target := hip + Vector2(lerpf(14.0, 18.0, sp), lerpf(12.0, 4.0, sp))
	var lead_ik := _solve_leg_ik(hip + Vector2(1.5, 0.0), lead_target, false)
	_draw_leg_points(hip + Vector2(1.5, 0.0), lead_ik["knee"], lead_ik["foot"], false, 0.3)

	# Torso and head
	_draw_torso_anatomical(hip, sho, lean, 0.0)
	_draw_neck(sho, neck)
	_draw_head_anatomical(hd, -lean * 0.5)

	# Both hands on edge
	var l_hand  := sho + Vector2(10.0, lerpf(2.0, 8.0, sp))
	var l_elbow := sho + Vector2(2.0, lerpf(8.0, 12.0, sp))
	_draw_arm_points(sho + Vector2(-2.0, 0.0), l_elbow, l_hand, true, true, 0.2)

	var r_hand  := sho + Vector2(14.0, lerpf(4.0, 10.0, sp))
	var r_elbow := sho + Vector2(6.0, lerpf(10.0, 14.0, sp))
	_draw_arm_points(sho + Vector2(2.0, 0.0), r_elbow, r_hand, false, true, 0.2)

# ── ANATOMICAL LIMB RENDERING & DISPATCH ───────────────────────

func _draw_neck(sho: Vector2, neck: Vector2) -> void:
	var dir  := (neck - sho).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var poly := PackedVector2Array([
		sho - perp * 3.8,
		sho + perp * 3.8,
		neck + perp * 2.8,
		neck - perp * 2.8
	])
	draw_colored_polygon(poly, C)
	draw_line(sho - perp * 3.2, neck - perp * 2.4, SHIRT_A_HI, 1.2, false)

func _draw_anatomical_leg(hip_pt: Vector2, thigh_ang: float, knee_bend: float, is_far: bool, flex: float = 0.0, foot_tilt: float = 0.0) -> void:
	var kb := clampf(knee_bend, deg_to_rad(15.0), deg_to_rad(140.0))
	var knee_pt : Vector2 = _tip(hip_pt, thigh_ang, UPR_LEG)
	var foot_pt : Vector2 = _tip(knee_pt, thigh_ang + kb, LWR_LEG)
	foot_pt.y = minf(foot_pt.y, FOOT_Y)
	_draw_leg_points(hip_pt, knee_pt, foot_pt, is_far, flex, foot_tilt)

func _draw_leg_points(hip_pt: Vector2, knee_pt: Vector2, foot_pt: Vector2, is_far: bool, flex: float = 0.0, foot_tilt: float = 0.0) -> void:
	var col_pants    : Color = PANTS.darkened(0.18) if is_far else PANTS
	var col_pants_hi : Color = PANTS_HI.darkened(0.18) if is_far else PANTS_HI
	var col_pants_sh : Color = PANTS_SH.darkened(0.18) if is_far else PANTS_SH

	# Width profile: thigh 11px, knee 8, calf 9, ankle 5
	var w0  : float = 11.0
	var wb1 : float = 11.8 + flex * 1.6
	var w1  : float = 8.0
	var wb2 : float = 9.2 + flex * 1.8
	var w2  : float = 5.0

	_draw_continuous_limb(hip_pt, knee_pt, foot_pt, w0, wb1, w1, wb2, w2, col_pants, col_pants_hi, col_pants_sh, true, is_far, flex)
	_draw_shoe(foot_pt, is_far, foot_tilt)

func _draw_shoe(foot_pt: Vector2, is_far: bool, foot_tilt: float = 0.0) -> void:
	var col_shoe : Color = SHOE_COL.darkened(0.2) if is_far else SHOE_COL
	var col_sole : Color = SHOE_SOLE.darkened(0.2) if is_far else SHOE_SOLE

	# Sculpted athletic shoe silhouette rotating with foot strike
	var p_ank    := foot_pt + (Vector2(-1.0, -2.2)).rotated(foot_tilt)
	var p_heel   := foot_pt + (Vector2(-3.8, 1.2)).rotated(foot_tilt)
	var p_base1  := foot_pt + (Vector2(-3.6, 3.8)).rotated(foot_tilt)
	var p_arch   := foot_pt + (Vector2(0.5, 3.2)).rotated(foot_tilt)
	var p_ball   := foot_pt + (Vector2(4.8, 3.8)).rotated(foot_tilt)
	var p_toe    := foot_pt + (Vector2(8.0, 2.2)).rotated(foot_tilt)
	var p_vamp   := foot_pt + (Vector2(4.2, 0.0)).rotated(foot_tilt)
	var p_tongue := foot_pt + (Vector2(1.2, -1.8)).rotated(foot_tilt)

	var shoe_pts := PackedVector2Array([
		p_ank, p_heel, p_base1, p_arch, p_ball, p_toe, p_vamp, p_tongue
	])
	draw_colored_polygon(shoe_pts, col_shoe)

	# Sole edge line (2-tone contrast)
	draw_line(p_base1, p_arch, col_sole, 1.6, false)
	draw_line(p_arch, p_ball, col_sole, 1.6, false)
	draw_line(p_ball, p_toe, col_sole, 1.4, false)
	draw_line(p_vamp, p_toe, col_sole * 0.9, 1.2, false)

func _draw_anatomical_arm(sho_pt: Vector2, upper_ang: float, is_far: bool, is_grip: bool = false, arc_offset: float = 0.0) -> void:
	var ua    : float = clampf(upper_ang, -PI * 0.40, PI * 1.70)
	var fwd   : float = clampf(1.0 - (ua / (PI * 0.5)), -1.0, 1.0)
	# Clamp elbow bend to human range [20°, 150°]
	var bend_target := ELBOW_BASE + maxf(0.0, fwd) * 0.50
	var bend  : float = clampf(bend_target, deg_to_rad(20.0), deg_to_rad(150.0))
	var fa    : float = clampf(ua - bend, -PI * 0.40, PI * 1.50)
	var elbow : Vector2 = _tip(sho_pt, ua, UPR_ARM)
	elbow.x += arc_offset
	var hand  : Vector2 = _tip(elbow, fa, LWR_ARM)

	var arm_lift : float = clampf((PI * 0.5 - ua) / (PI * 0.5), 0.0, 1.4)
	var adj_sho  : Vector2 = sho_pt + Vector2(0.0, -arm_lift * 1.6)

	_draw_arm_points(adj_sho, elbow, hand, is_far, is_grip, arm_lift)

func _draw_arm_points(sho_pt: Vector2, elbow_pt: Vector2, hand_pt: Vector2, is_far: bool, is_grip: bool, arm_lift: float = 0.0) -> void:
	var col_shirt_a : Color = SHIRT_A.darkened(0.2) if is_far else SHIRT_A
	var col_shirt_hi: Color = SHIRT_A_HI.darkened(0.18) if is_far else SHIRT_A_HI
	var col_crease  : Color = Color(0.08, 0.08, 0.10).darkened(0.2) if is_far else Color(0.08, 0.08, 0.10)

	# Width profile for arm: shoulder 9px, bicep 8.2px, elbow 6.5px, forearm 7.4px, wrist 4.4px
	var w0  : float = 9.0 + arm_lift * 1.2
	var wb1 : float = 8.2 + arm_lift * 0.8
	var w1  : float = 6.5
	var wb2 : float = 7.4
	var w2  : float = 4.4

	_draw_continuous_limb(sho_pt, elbow_pt, hand_pt, w0, wb1, w1, wb2, w2, col_shirt_a, col_shirt_hi, col_crease, false, is_far, arm_lift)

	# Sculpted hand at wrist
	var u_f := (hand_pt - elbow_pt).normalized()
	var n_f := Vector2(-u_f.y, u_f.x)
	_draw_hand(hand_pt, u_f, n_f, is_grip, is_far)

func _draw_hand(hand_pt: Vector2, u_f: Vector2, n_f: Vector2, is_grip: bool, is_far: bool) -> void:
	var col_skin    : Color = SKIN_TONE.darkened(0.2) if is_far else SKIN_TONE
	var col_skin_hi : Color = SKIN_HI.darkened(0.18) if is_far else SKIN_HI

	if is_grip:
		var p_palm := hand_pt + u_f * 2.2
		draw_circle(p_palm, 3.4, col_skin)
		draw_circle(p_palm + n_f * 0.8, 2.2, col_skin_hi)
		var thumb_tip := p_palm + n_f * 2.4 - u_f * 0.8
		draw_line(p_palm - n_f * 1.5, thumb_tip, col_skin, 2.2, true)
		draw_circle(thumb_tip, 1.2, col_skin_hi)
	else:
		var p_knuckle := hand_pt + u_f * 3.6
		var palm_pts := PackedVector2Array([
			hand_pt + n_f * 2.0,
			p_knuckle + n_f * 1.8,
			p_knuckle - n_f * 1.6,
			hand_pt - n_f * 1.8
		])
		draw_colored_polygon(palm_pts, col_skin)
		draw_line(hand_pt + n_f * 1.6, p_knuckle + n_f * 1.4, col_skin_hi, 1.2, false)
		var thumb_root := hand_pt + u_f * 0.8 + n_f * 1.8
		var thumb_tip  := thumb_root + u_f * 2.0 + n_f * 2.2
		draw_line(thumb_root, thumb_tip, col_skin, 1.8, true)
		draw_circle(thumb_tip, 1.0, col_skin_hi)

# ── ANATOMICAL TORSO & HEAD ───────────────────────────────────

func _draw_torso_anatomical(hip_pt: Vector2, sho_pt: Vector2, lean: float, reach_rot: float = 0.0) -> void:
	var eff_lean : float = lean + reach_rot
	var perp     : Vector2 = Vector2(cos(eff_lean), sin(eff_lean))

	# Athletic V-taper torso polygon with rounded shoulder and hip blends
	var p_sho_r := sho_pt + perp * SHO_HW
	var p_sho_l := sho_pt - perp * SHO_HW
	var p_hip_l := hip_pt - perp * HIP_HW
	var p_hip_r := hip_pt + perp * HIP_HW

	var p_mid_r := sho_pt.lerp(hip_pt, 0.40) + perp * (SHO_HW * 0.88)
	var p_mid_l := sho_pt.lerp(hip_pt, 0.40) - perp * (SHO_HW * 0.84)

	var base_torso := PackedVector2Array([
		p_sho_r, p_mid_r, p_hip_r, p_hip_l, p_mid_l, p_sho_l
	])
	draw_colored_polygon(base_torso, C)

	# Alternating striped shirt matching upper sleeves without joint discs
	var num_stripes : int = 6
	for j : int in num_stripes:
		var t0 : float = float(j) / float(num_stripes)
		var t1 : float = float(j + 1) / float(num_stripes)
		var p_a : Vector2 = sho_pt.lerp(hip_pt, t0)
		var p_b : Vector2 = sho_pt.lerp(hip_pt, t1)
		var w0  : float = lerpf(SHO_HW, HIP_HW, t0) - 0.4
		var w1  : float = lerpf(SHO_HW, HIP_HW, t1) - 0.4
		var stripe_pts := PackedVector2Array([
			p_a + perp * w0,
			p_a - perp * w0,
			p_b - perp * w1,
			p_b + perp * w1
		])
		var stripe_col : Color = SHIRT_B if (j % 2 == 1) else SHIRT_A
		draw_colored_polygon(stripe_pts, stripe_col)
		var stripe_hi_col : Color = SHIRT_B_SH if (j % 2 == 1) else SHIRT_A_HI
		draw_line(p_a + perp * w0, p_b + perp * w1, stripe_hi_col, 1.4, false)

	# Pelvis waistband seamlessly blending torso into pants
	var pelvis_pts := PackedVector2Array([
		hip_pt - perp * (HIP_HW + 0.5),
		hip_pt + perp * (HIP_HW + 0.5),
		hip_pt + perp * (HIP_HW + 0.5) + Vector2(0.0, 3.5),
		hip_pt - perp * (HIP_HW + 0.5) + Vector2(0.0, 3.5)
	])
	draw_colored_polygon(pelvis_pts, PANTS)

	# Cyber Data Drive & trailing neon scarf
	var sack_anchor := sho_pt + perp * (-SHO_HW * 0.65) + Vector2(-2.0, 3.0)
	var sack_center := sack_anchor + _bag_lag_offset

	# Trailing neon energy scarf / ribbon
	var scarf_base := sho_pt + Vector2(-2.0, -2.0)
	var scarf_mid  := scarf_base + Vector2(-9.0, 2.0) + _bag_lag_offset * 0.8
	var scarf_tip1 := scarf_base + Vector2(-18.0, -1.0) + _bag_lag_offset * 1.5
	var scarf_tip2 := scarf_base + Vector2(-16.0, 5.0) + _bag_lag_offset * 1.3
	draw_line(scarf_base, scarf_mid, SACK_TIE, 2.8, true)
	draw_line(scarf_mid, scarf_tip1, SACK_TIE, 2.0, true)
	draw_line(scarf_mid, scarf_tip2, Color(0.0, 0.92, 0.98, 0.6), 1.4, true)

	# Hexagonal Cyber Data Core
	var core_pts := PackedVector2Array()
	var core_r : float = 5.5
	for i in range(6):
		var ang : float = TAU * float(i) / 6.0
		core_pts.append(sack_center + Vector2(cos(ang), sin(ang)) * core_r)
	draw_colored_polygon(core_pts, SACK_COL)
	# Glowing center core
	draw_circle(sack_center, 2.4, SACK_HI)
	draw_circle(sack_center, 1.2, Color(1, 1, 1, 0.9))
	# Cable attachment to suit
	draw_line(sack_anchor + Vector2(2.0, -1.0), sack_center, SACK_TIE, 1.8, false)

func _draw_head_anatomical(center: Vector2, head_tilt: float = 0.0) -> void:
	var steps : int = 24
	var skull_pts := PackedVector2Array()
	var r_x : float = HEAD_R * 1.05
	var r_y : float = HEAD_R * 0.96

	for i in range(steps):
		var a : float = TAU * float(i) / float(steps)
		var p_local := Vector2(cos(a) * r_x, sin(a) * r_y)
		if a > 0.1 and a < PI * 0.5:
			p_local *= 0.94
		skull_pts.append(center + p_local.rotated(head_tilt))
	draw_colored_polygon(skull_pts, C)

	# Cyber Ninja Cowl / Hood
	var cowl_pts := PackedVector2Array()
	var b_steps : int = 14
	for i in range(b_steps + 1):
		var t : float = float(i) / float(b_steps)
		var a : float = PI * 0.98 - t * (PI * 0.96)
		var p_b := Vector2(cos(a) * r_x * 1.08, sin(a) * r_y * 1.04).rotated(head_tilt)
		cowl_pts.append(center + p_b)

	var brim_r := (Vector2(r_x * 0.92, -0.6)).rotated(head_tilt)
	var brim_l := (Vector2(-r_x * 0.92, -0.6)).rotated(head_tilt)
	cowl_pts.append(center + brim_r)
	cowl_pts.append(center + brim_l)
	draw_colored_polygon(cowl_pts, BEANIE)

	# Hood carbon edge trim
	draw_line(center + brim_l, center + brim_r, BEANIE_HI, 2.0, false)

	# Sleek glowing cyan cyber visor (high-tech optics slit)
	var visor_dir    := Vector2(1.0, 0.0).rotated(head_tilt)
	var visor_offset := Vector2(2.2, 0.8).rotated(head_tilt)
	var visor_p1     := center + visor_offset - visor_dir * 3.0
	var visor_p2     := center + visor_offset + visor_dir * (HEAD_R * 0.85)

	# Visor housing (dark border)
	draw_line(visor_p1, visor_p2, MASK_BG, 3.8, true)
	# Glowing cyan visor beam
	draw_line(visor_p1 + visor_dir * 0.8, visor_p2, MASK_HOLE, 2.0, true)
	# Visor bright laser flare dot at front
	draw_circle(visor_p2, 1.4, Color(1, 1, 1, 0.95))
