extends "res://scripts/PlayerVisual.gd"
## Procedural human silhouette for the Chaser (Robo-Samurai Enforcer).
## Extends PlayerVisual.gd to reuse continuous limb generation, fold pinch math, and IK helpers.
## Mechanical samurai armor plates, red glowing joints, energy katana, kabuto helmet.

# ── Robo-Samurai Armor Palette ─────────────────────────────────
const CHASER_SHIRT     : Color = Color(0.10, 0.10, 0.18)  # gunmetal armor plate base
const CHASER_SHIRT_HI  : Color = Color(0.22, 0.22, 0.35)  # armor highlight (brushed metal)
const CHASER_SHIRT_SH  : Color = Color(0.04, 0.04, 0.08)  # armor shadow / panel crease
const CHASER_PANTS     : Color = Color(0.08, 0.08, 0.16)  # matte black leg armor
const CHASER_PANTS_HI  : Color = Color(0.18, 0.18, 0.28)  # leg plate highlight
const CHASER_PANTS_SH  : Color = Color(0.03, 0.03, 0.06)  # leg shadow
const CHASER_BADGE     : Color = Color(1.00, 0.10, 0.24)  # red glowing power crystal
const CHASER_BELT      : Color = Color(0.06, 0.06, 0.12)  # black utility belt
const CHASER_BUCKLE    : Color = Color(1.00, 0.10, 0.24)  # glowing red belt core
const CHASER_CAP       : Color = Color(0.08, 0.08, 0.18)  # kabuto helmet main plate
const CHASER_CAP_HI    : Color = Color(0.18, 0.18, 0.30)  # helmet highlight
const CHASER_CAP_PEAK  : Color = Color(1.00, 0.10, 0.24)  # red glowing visor
const CHASER_GLOVE     : Color = Color(0.08, 0.08, 0.16)  # black mechanical gauntlets
const CHASER_GLOVE_HI  : Color = Color(0.18, 0.18, 0.28)  # gauntlet highlight
const CHASER_GUN       : Color = Color(0.85, 0.12, 0.20)  # energy katana blade (red)
const CHASER_GUN_HI    : Color = Color(1.00, 0.55, 0.60)  # katana bright edge highlight

# ── Bulkier Anatomical Proportions ─────────────────────────────
# Shoulders: about 2.3x head width (head width = 12.4px -> 28.5px, half-width = 14.2px)
const C_SHO_HW   : float = 14.2   # broad muscular shoulder line (2.3x head width)
const C_HIP_HW   : float = 7.6    # solid waist / hips
const C_UPR_ARM  : float = 14.5
const C_LWR_ARM  : float = 12.5
const C_ARM_SWING: float = 1.02   # heavier, powerful arm swing

# Gun tip for muzzle flash
var gun_tip_pos : Vector2 = Vector2.ZERO

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var p := get_parent()
	if not p or not p.visible:
		return

	var c_scale : float = float(p.CHARACTER_SCALE) if ("CHARACTER_SCALE" in p) else 1.25
	# 2D Matrix Transformations (3x3 Homogeneous Coordinates from stage3v2.cpp)
	var S := ClipAlgorithms.mat_scaling(c_scale, c_scale)
	var T := ClipAlgorithms.mat_translation(0.0, FOOT_Y * (1.0 - c_scale))
	var M := ClipAlgorithms.mat_multiply(T, S)
	draw_set_transform_matrix(ClipAlgorithms.to_transform2d(M))

	var st : String = str(p.get("_ai_state")) if p.get("_ai_state") else "run"
	match st:
		"run":
			_draw_chaser_run()
		"jump", "fall":
			var vy : float = float(p.get("_vel_y")) if p.get("_vel_y") != null else 0.0
			_draw_chaser_air(vy)
		"slide":
			_draw_chaser_slide()
		"grab":
			_draw_chaser_grab()
		_:
			_draw_chaser_run()

	var show_fl : bool = bool(p.get("_show_flash")) if p.get("_show_flash") != null else false
	if show_fl and gun_tip_pos.length() > 1.0:
		draw_circle(gun_tip_pos, 8.0, Color(1.0, 0.2, 0.3, 0.8))
		draw_circle(gun_tip_pos, 4.0, Color(1.0, 0.9, 0.9, 1.0))

# ── RUN (Aggressive Forward Lean, Heavy Arm Swing, Bulkier Continuous Limbs) ──
func _draw_chaser_run() -> void:
	var p := get_parent()
	var t : float = float(p.get("_anim_time")) if (p and p.get("_anim_time") != null) else 0.0

	# Aggressive forward lean while running
	var lean : float = 0.35 + sin(t * 2.0) * 0.03
	var sq   : float = 0.0
	var l_sq : float = float(p.get("_land_squash")) if (p and p.get("_land_squash") != null) else 0.0
	if l_sq > 0.0:
		var st_sq : float = clampf(l_sq, 0.0, 1.0)
		sq = st_sq * st_sq * (3.0 - 2.0 * st_sq)
		lean += 0.16 * sq

	# Heavy body bob of about 2.2px
	var bob : float = sin(t * 2.0 - PI * 0.5) * 2.2

	# Transverse Hip Rotation
	var hip_rot : float = sin(t) * 0.08
	var lead_hip_offset : Vector2 = Vector2(hip_rot * 24.0, 0.0)

	var hip_base : Vector2 = Vector2(0.0, HIP_Y + bob + 3.8 * sq)
	var sho_base : Vector2 = _tip(hip_base, -PI * 0.5 + lean, TORSO_H)
	var neck     : Vector2 = _tip(sho_base, -PI * 0.5 + lean, NECK_H)
	var hd       : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	# 4-Phase Leg Kinematics with heavier muscle bulges
	var leg_data := []
	for i : int in 2:
		var phase : float = t if i == 0 else t + PI
		var w : float = fposmod(phase, TAU) / TAU
		var thigh_ang : float
		var knee_bend : float
		var foot_tilt : float
		var push_flex : float = 0.0

		if w < 0.50:
			var s : float = w / 0.50
			thigh_ang = (PI * 0.5) - lerpf(0.48, -0.42, _smooth(s))
			if s < 0.25:
				var sub := s / 0.25
				knee_bend = lerpf(deg_to_rad(24.0), deg_to_rad(42.0), _smooth(sub))
				foot_tilt = lerpf(-0.30, -0.05, _smooth(sub))
			elif s < 0.65:
				var sub := (s - 0.25) / 0.40
				knee_bend = lerpf(deg_to_rad(42.0), deg_to_rad(52.0), sin(sub * PI))
				foot_tilt = 0.0
			else:
				var sub := (s - 0.65) / 0.35
				knee_bend = lerpf(deg_to_rad(42.0), deg_to_rad(18.0), _smooth(sub))
				foot_tilt = lerpf(0.0, 0.52, _smooth(sub))
				push_flex = sin(sub * PI)
		else:
			var r : float = (w - 0.50) / 0.50
			if r < 0.45:
				var sub := r / 0.45
				knee_bend = lerpf(deg_to_rad(26.0), deg_to_rad(112.0), _smooth(sub))
				thigh_ang = (PI * 0.5) - lerpf(-0.42, 0.14, _smooth(sub))
				foot_tilt = 0.35
			else:
				var sub := (r - 0.45) / 0.55
				knee_bend = lerpf(deg_to_rad(112.0), deg_to_rad(24.0), _smooth(sub))
				thigh_ang = (PI * 0.5) - lerpf(0.14, 0.48, _smooth(sub))
				foot_tilt = lerpf(0.35, -0.30, _smooth(sub))

		if sq > 0.0:
			knee_bend += 0.60 * sq

		leg_data.append({
			"thigh": thigh_ang,
			"knee": clampf(knee_bend, deg_to_rad(15.0), deg_to_rad(140.0)),
			"tilt": foot_tilt,
			"flex": push_flex
		})

	# Heavy arm swing
	var asw : float = cos(t) * C_ARM_SWING
	var base_arm : float = PI * 0.5 + lean
	var a_free   : float = base_arm - asw
	var gun_ang  : float = base_arm + asw * 0.35

	var arc_free : float = -sin(t) * 3.5
	var arc_gun  : float = sin(t) * 1.5

	if sq > 0.0:
		a_free  = lerpf(a_free,  PI * 0.5 + lean - 0.45, sq * 0.75)
		gun_ang = lerpf(gun_ang, PI * 0.5 + lean - 0.35, sq * 0.75)

	var torso_twist : float = -asw * 0.05

	# 1. Far leg (trailing leg index 1)
	var hip_far := hip_base - lead_hip_offset
	_draw_chaser_leg(hip_far, leg_data[1]["thigh"], leg_data[1]["knee"], true, leg_data[1]["flex"], leg_data[1]["tilt"])
	# 2. Far arm (free arm swinging heavily)
	var sho_far := sho_base - lead_hip_offset * 0.5
	_draw_chaser_arm(sho_far, a_free, true, false, 0.0, arc_free)
	# 3. Muscular broad torso & neck
	_draw_chaser_torso(hip_base, sho_base, lean, torso_twist)
	_draw_neck(sho_base, neck)
	# 4. Near leg (lead leg index 0)
	var hip_near := hip_base + lead_hip_offset
	_draw_chaser_leg(hip_near, leg_data[0]["thigh"], leg_data[0]["knee"], false, leg_data[0]["flex"], leg_data[0]["tilt"])
	# 5. Near arm (holding pistol forward)
	var sho_near := sho_base + lead_hip_offset * 0.5
	_draw_chaser_arm(sho_near, gun_ang, false, true, 0.32, arc_gun)
	# 6. Chaser head & police cap (level gaze)
	_draw_chaser_head(hd, -lean)

# ── AIRBORNE (Muscular Anticipation, Extension, Tuck, Landing) ──
func _draw_chaser_air(vel_y: float) -> void:
	var p := get_parent()
	var hip_y       : float = 0.0
	var lean        : float = 0.30
	var lead_thigh  : float = 0.0
	var lead_knee   : float = 0.0
	var trail_thigh : float = 0.0
	var trail_knee  : float = 0.0
	var arm_free    : float = 0.0
	var arm_gun     : float = 0.0

	if vel_y < 0.0:
		var raw_u : float = clampf((vel_y - (-260.0)) / 260.0, 0.0, 1.0)
		var u     : float = _smooth(raw_u)
		hip_y       = lerpf(-3.0, -5.5, u)
		lean        = lerpf(0.32, 0.26, u)
		lead_thigh  = lerpf(0.32, 0.12, u)
		lead_knee   = lerpf(deg_to_rad(45.0), deg_to_rad(92.0), u)
		trail_thigh = lerpf(PI * 0.5 + 0.38, 0.42, u)
		trail_knee  = lerpf(deg_to_rad(35.0), deg_to_rad(88.0), u)
		arm_free    = lerpf(PI * 0.5 + lean + 0.65, PI * 0.5 + lean - 0.40, u)
		arm_gun     = lerpf(PI * 0.5 + lean - 0.70, PI * 0.5 + lean - 0.50, u)
	else:
		var raw_u : float = clampf(vel_y / 260.0, 0.0, 1.0)
		var u     : float = _smooth(raw_u)
		hip_y       = lerpf(-5.5, -1.0, u)
		lean        = lerpf(0.26, 0.22, u)
		lead_thigh  = lerpf(0.12, PI * 0.5 - 0.28, u)
		lead_knee   = lerpf(deg_to_rad(92.0), deg_to_rad(35.0), u)
		trail_thigh = lerpf(0.42, PI * 0.5 + 0.08, u)
		trail_knee  = lerpf(deg_to_rad(88.0), deg_to_rad(32.0), u)
		arm_free    = lerpf(PI * 0.5 + lean - 0.40, PI * 0.5 + lean + 0.45, u)
		arm_gun     = lerpf(PI * 0.5 + lean - 0.50, PI * 0.5 + lean - 0.35, u)

	# Take-off blend
	var j_time : float = float(p.get("_jump_time")) if (p and p.get("_jump_time") != null) else 1.0
	if j_time < 0.08:
		var raw_to : float = clampf(j_time / 0.08, 0.0, 1.0)
		var w_to   : float = 1.0 - _smooth(raw_to)
		var to_hip_y       : float = 0.0
		var to_lean        : float = 0.32
		var to_lead_thigh  : float = PI * 0.5
		var to_lead_knee   : float = deg_to_rad(100.0)
		var to_trail_thigh : float = PI * 0.5
		var to_trail_knee  : float = deg_to_rad(100.0)
		var to_arm_free    : float = PI * 0.5 + lean + 0.45
		var to_arm_gun     : float = PI * 0.5 + lean + 0.45

		if raw_to >= 0.5:
			var sub : float = (raw_to - 0.5) / 0.5
			var s_sub := _smooth(sub)
			to_hip_y       = lerpf(4.5, -3.5, s_sub)
			to_lean        = lerpf(0.38, 0.24, s_sub)
			to_lead_thigh  = lerpf(PI * 0.5, PI * 0.5 + 0.30, s_sub)
			to_lead_knee   = lerpf(deg_to_rad(100.0), deg_to_rad(18.0), s_sub)
			to_trail_thigh = lerpf(PI * 0.5, PI * 0.5 + 0.36, s_sub)
			to_trail_knee  = lerpf(deg_to_rad(100.0), deg_to_rad(18.0), s_sub)
			to_arm_free    = lerpf(PI * 0.5 + to_lean + 0.45, PI * 0.5 + to_lean - 0.85, s_sub)
			to_arm_gun     = lerpf(PI * 0.5 + to_lean + 0.45, PI * 0.5 + to_lean - 0.65, s_sub)

		hip_y       = lerpf(hip_y, to_hip_y, w_to)
		lean        = lerpf(lean, to_lean, w_to)
		lead_thigh  = lerpf(lead_thigh, to_lead_thigh, w_to)
		lead_knee   = lerpf(lead_knee, to_lead_knee, w_to)
		trail_thigh = lerpf(trail_thigh, to_trail_thigh, w_to)
		trail_knee  = lerpf(trail_knee, to_trail_knee, w_to)
		arm_free    = lerpf(arm_free, to_arm_free, w_to)
		arm_gun     = lerpf(arm_gun, to_arm_gun, w_to)

	var hip : Vector2 = Vector2(0.0, HIP_Y + hip_y)
	var sho : Vector2 = _tip(hip, -PI * 0.5 + lean, TORSO_H)
	var neck: Vector2 = _tip(sho, -PI * 0.5 + lean, NECK_H)
	var hd  : Vector2 = _tip(neck, -PI * 0.5 + lean, HEAD_R)

	_draw_chaser_leg(hip, trail_thigh, trail_knee, true, 0.25)
	_draw_chaser_arm(sho, arm_free, true, false)
	_draw_chaser_torso(hip, sho, lean, 0.0)
	_draw_neck(sho, neck)
	_draw_chaser_leg(hip, lead_thigh, lead_knee, false, 0.15)
	_draw_chaser_arm(sho, arm_gun, false, true, 0.15)
	_draw_chaser_head(hd, -lean)

# ── SLIDE ─────────────────────────────────────────────────────
func _draw_chaser_slide() -> void:
	var p := get_parent()
	var s_blend : float = float(p.get("_slide_blend")) if (p and p.get("_slide_blend") != null) else 1.0
	var lean    : float = -0.55
	var pivot_y : float = HIP_Y + lerpf(4.0, 12.0, s_blend)
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

	_draw_chaser_leg_points(pivot, knee_b, foot_b, true, 0.3)
	var arm_far_elbow := sho + Vector2(-6.0, 5.0)
	var arm_far_hand  := arm_far_elbow + Vector2(7.0, 2.0)
	_draw_chaser_arm_points(sho + Vector2(-2.0, 0.0), arm_far_elbow, arm_far_hand, true, false)

	_draw_chaser_torso(pivot, sho, lean, 0.0)
	_draw_neck(sho, neck)

	_draw_chaser_leg_points(pivot, knee_f, foot_f, false, 0.4)
	var arm_near_elbow := sho + Vector2(4.0, 6.0)
	var arm_near_hand  := arm_near_elbow + Vector2(7.0, 1.0)
	_draw_chaser_arm_points(sho + Vector2(2.0, 0.0), arm_near_elbow, arm_near_hand, false, true, 0.0, 0.0)
	_draw_chaser_head(hd, 0.25)

# ── GRAB / AIM (Arrests player with drawn gun & muzzle flash) ──
func _draw_chaser_grab() -> void:
	var lean : float   = -0.20
	var hip  : Vector2 = Vector2(4.0, HIP_Y + 2.0)
	var sho  : Vector2 = _tip(hip, lean - PI * 0.5, TORSO_H)
	var neck : Vector2 = _tip(sho, lean - PI * 0.5, NECK_H)
	var hd   : Vector2 = _tip(neck, lean - PI * 0.5, HEAD_R)

	_draw_chaser_leg(hip, PI * 0.5 + lean + 0.35, deg_to_rad(25.0), true, 0.2)
	_draw_chaser_leg(hip, PI * 0.5 + lean - 0.15, deg_to_rad(18.0), false, 0.2)

	_draw_chaser_torso(hip, sho, lean, 0.0)
	_draw_neck(sho, neck)

	# Free arm bracing back
	_draw_chaser_arm(sho, PI * 0.5 + lean + 1.0, true, false)

	# Gun arm leveling pistol straight at target
	var gun_ang : float = PI * 0.5 + lean - 0.75
	_draw_chaser_arm(sho, gun_ang, false, true, -0.12)

	_draw_chaser_head(hd, -0.10)

# ── CHASER BULKY CONTINUOUS LIMB RENDERING ─────────────────────

func _draw_chaser_leg(hip_pt: Vector2, thigh_ang: float, knee_bend: float, is_far: bool, flex: float = 0.0, foot_tilt: float = 0.0) -> void:
	var kb := clampf(knee_bend, deg_to_rad(15.0), deg_to_rad(140.0))
	var knee_pt : Vector2 = _tip(hip_pt, thigh_ang, UPR_LEG)
	var foot_pt : Vector2 = _tip(knee_pt, thigh_ang + kb, LWR_LEG)
	foot_pt.y = minf(foot_pt.y, FOOT_Y)
	_draw_chaser_leg_points(hip_pt, knee_pt, foot_pt, is_far, flex, foot_tilt)

func _draw_chaser_leg_points(hip_pt: Vector2, knee_pt: Vector2, foot_pt: Vector2, is_far: bool, flex: float = 0.0, foot_tilt: float = 0.0) -> void:
	var col_pants    : Color = CHASER_PANTS.darkened(0.2) if is_far else CHASER_PANTS
	var col_pants_hi : Color = CHASER_PANTS_HI.darkened(0.18) if is_far else CHASER_PANTS_HI
	var col_pants_sh : Color = CHASER_PANTS_SH.darkened(0.2) if is_far else CHASER_PANTS_SH

	# Bulkier leg width profile: hip 14.2px, quad 15.6px, knee 10.5px, calf 12.2px, ankle 6.5px
	var w0  : float = 14.2
	var wb1 : float = 15.6 + flex * 2.2
	var w1  : float = 10.5
	var wb2 : float = 12.2 + flex * 2.4
	var w2  : float = 6.5

	_draw_continuous_limb(hip_pt, knee_pt, foot_pt, w0, wb1, w1, wb2, w2, col_pants, col_pants_hi, col_pants_sh, true, is_far, flex)
	_draw_shoe(foot_pt, is_far, foot_tilt)

func _draw_chaser_arm(sho_pt: Vector2, upper_ang: float, is_far: bool, is_gun_arm: bool = false, gun_tilt: float = 0.0, arc_offset: float = 0.0) -> void:
	var ua    : float = clampf(upper_ang, -PI * 0.40, PI * 1.70)
	var fwd   : float = clampf(1.0 - (ua / (PI * 0.5)), -1.0, 1.0)
	var bend_target := ELBOW_BASE + maxf(0.0, fwd) * 0.45
	var bend  : float = clampf(bend_target, deg_to_rad(20.0), deg_to_rad(150.0))
	var fa    : float = clampf(ua - bend, -PI * 0.40, PI * 1.50)
	var elbow : Vector2 = _tip(sho_pt, ua, C_UPR_ARM)
	elbow.x += arc_offset
	var hand  : Vector2 = _tip(elbow, fa, C_LWR_ARM)

	var arm_lift : float = clampf((PI * 0.5 - ua) / (PI * 0.5), 0.0, 1.4)
	var adj_sho  : Vector2 = sho_pt + Vector2(0.0, -arm_lift * 1.8)

	_draw_chaser_arm_points(adj_sho, elbow, hand, is_far, is_gun_arm, arm_lift, gun_tilt)

func _draw_chaser_arm_points(sho_pt: Vector2, elbow_pt: Vector2, hand_pt: Vector2, is_far: bool, is_gun_arm: bool, arm_lift: float = 0.0, gun_tilt: float = 0.0) -> void:
	var col_shirt    : Color = CHASER_SHIRT.darkened(0.2) if is_far else CHASER_SHIRT
	var col_shirt_hi : Color = CHASER_SHIRT_HI.darkened(0.18) if is_far else CHASER_SHIRT_HI
	var col_shirt_sh : Color = CHASER_SHIRT_SH.darkened(0.2) if is_far else CHASER_SHIRT_SH

	# Bulkier muscular arm width profile: shoulder 12.2px, bicep 11.4px, elbow 8.8px, forearm 10.0px, wrist 6.0px
	var w0  : float = 12.2 + arm_lift * 1.5
	var wb1 : float = 11.4 + arm_lift * 1.0
	var w1  : float = 8.8
	var wb2 : float = 10.0
	var w2  : float = 6.0

	_draw_continuous_limb(sho_pt, elbow_pt, hand_pt, w0, wb1, w1, wb2, w2, col_shirt, col_shirt_hi, col_shirt_sh, false, is_far, arm_lift)

	# Hand or Pistol
	var u_f := (hand_pt - elbow_pt).normalized()
	var n_f := Vector2(-u_f.y, u_f.x)
	if is_gun_arm:
		_draw_hand(hand_pt, u_f, n_f, true, is_far)
		_draw_chaser_pistol(hand_pt, gun_tilt)
	else:
		_draw_hand(hand_pt, u_f, n_f, true, is_far)

func _draw_chaser_pistol(hand_pos: Vector2, ang: float) -> void:
	var fwd  : Vector2 = Vector2(cos(ang), sin(ang))
	var down : Vector2 = Vector2(-fwd.y, fwd.x)
	var tip  : Vector2 = hand_pos + fwd * 25.0
	gun_tip_pos = tip

	# Katana Tsuka (hilt grip extending behind hand)
	draw_line(hand_pos - fwd * 7.5, hand_pos, Color(0.12, 0.12, 0.20), 3.4, false)
	draw_line(hand_pos - fwd * 7.5, hand_pos, Color(0.04, 0.04, 0.08), 1.6, false)

	# Tsuba (crossguard at hand front)
	draw_line(hand_pos - down * 3.5, hand_pos + down * 3.5, Color(0.24, 0.24, 0.35), 2.4, false)

	# Thermal energy blade core (long crimson laser blade)
	draw_line(hand_pos + fwd * 1.0, tip, CHASER_GUN, 3.2, false)
	# Plasma razor cutting edge (bright white/pink highlight)
	draw_line(hand_pos + fwd * 2.0 - down * 0.8, tip - down * 0.4, CHASER_GUN_HI, 1.5, false)
	# Blade tip flare
	draw_circle(tip, 1.8, Color(1.0, 0.6, 0.7, 0.9))

func _draw_chaser_torso(hip_pt: Vector2, sho_pt: Vector2, lean: float, reach_rot: float = 0.0) -> void:
	var eff_lean : float = lean + reach_rot
	var perp     : Vector2 = Vector2(cos(eff_lean), sin(eff_lean))

	# Shoulders: about 2.3x head width (C_SHO_HW = 14.2)
	var p_sho_r := sho_pt + perp * C_SHO_HW
	var p_sho_l := sho_pt - perp * C_SHO_HW
	var p_hip_l := hip_pt - perp * C_HIP_HW
	var p_hip_r := hip_pt + perp * C_HIP_HW

	# Chest expansion at pectorals
	var p_mid_r := sho_pt.lerp(hip_pt, 0.38) + perp * (C_SHO_HW * 0.92)
	var p_mid_l := sho_pt.lerp(hip_pt, 0.38) - perp * (C_SHO_HW * 0.88)

	var torso_pts := PackedVector2Array([
		p_sho_r, p_mid_r, p_hip_r, p_hip_l, p_mid_l, p_sho_l
	])
	draw_colored_polygon(torso_pts, CHASER_SHIRT)

	# 2-tone highlight along front chest
	var chest_hi := PackedVector2Array([
		p_sho_r, p_mid_r, p_hip_r,
		hip_pt + perp * 2.0, sho_pt.lerp(hip_pt, 0.38) + perp * 2.0, sho_pt + perp * 2.0
	])
	draw_colored_polygon(chest_hi, CHASER_SHIRT_HI)

	# Officer brass badge on chest
	var badge_pos := sho_pt.lerp(hip_pt, 0.34) + perp * 4.5
	draw_circle(badge_pos, 2.2, CHASER_BADGE)
	draw_circle(badge_pos + Vector2(0.5, -0.5), 1.0, Color.WHITE)

	# Duty belt & pelvic waistband seamlessly blending torso into trousers
	var pelvis_pts := PackedVector2Array([
		hip_pt - perp * (C_HIP_HW + 0.5),
		hip_pt + perp * (C_HIP_HW + 0.5),
		hip_pt + perp * (C_HIP_HW + 0.5) + Vector2(0.0, 3.8),
		hip_pt - perp * (C_HIP_HW + 0.5) + Vector2(0.0, 3.8)
	])
	draw_colored_polygon(pelvis_pts, CHASER_PANTS)

	var b_left  := hip_pt - perp * (C_HIP_HW - 0.4)
	var b_right := hip_pt + perp * (C_HIP_HW - 0.4)
	draw_line(b_left, b_right, CHASER_BELT, 3.2, false)
	draw_circle(hip_pt, 1.6, CHASER_BUCKLE)

func _draw_chaser_head(center: Vector2, head_tilt: float = 0.0) -> void:
	var steps : int = 24
	var skull_pts := PackedVector2Array()
	var r_x : float = HEAD_R * 1.08
	var r_y : float = HEAD_R * 0.98

	for i in range(steps):
		var a : float = TAU * float(i) / float(steps)
		var p_local := Vector2(cos(a) * r_x, sin(a) * r_y)
		if a > 0.1 and a < PI * 0.5:
			p_local *= 0.95
		skull_pts.append(center + p_local.rotated(head_tilt))
	draw_colored_polygon(skull_pts, C)

	# Dark police cap crown
	var cap_pts := PackedVector2Array([
		center + (Vector2(-HEAD_R * 0.90, -1.0)).rotated(head_tilt),
		center + (Vector2(-HEAD_R * 0.75, -HEAD_R * 1.15)).rotated(head_tilt),
		center + (Vector2(HEAD_R * 0.85, -HEAD_R * 1.25)).rotated(head_tilt),
		center + (Vector2(HEAD_R * 1.05, -2.2)).rotated(head_tilt),
		center + (Vector2(HEAD_R * 0.45, -1.0)).rotated(head_tilt)
	])
	draw_colored_polygon(cap_pts, CHASER_CAP)

	# Cap band & highlight
	var b_start := center + (Vector2(-HEAD_R * 0.90, -1.5)).rotated(head_tilt)
	var b_end   := center + (Vector2(HEAD_R * 1.05, -2.5)).rotated(head_tilt)
	draw_line(b_start, b_end, CHASER_CAP_HI, 2.4, false)

	# Visor / peak projecting forward
	var v_start := center + (Vector2(HEAD_R * 0.65, -2.0)).rotated(head_tilt)
	var v_end   := center + (Vector2(HEAD_R * 1.55, -1.5)).rotated(head_tilt)
	draw_line(v_start, v_end, CHASER_CAP_PEAK, 2.5, false)

	# Brass badge pin on cap front
	var cap_badge := center + (Vector2(HEAD_R * 0.55, -HEAD_R * 0.70)).rotated(head_tilt)
	draw_circle(cap_badge, 1.6, CHASER_BADGE)
