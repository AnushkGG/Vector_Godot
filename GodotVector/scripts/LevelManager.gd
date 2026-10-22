extends Node2D

@onready var player       = $Player
@onready var hud_score    = $CanvasLayer/HUD/Score
@onready var hud_coins    = $CanvasLayer/HUD/Coins
@onready var hud_diamonds = $CanvasLayer/HUD/Diamonds
@onready var sfx_coin     = $SfxCoin
@onready var ui           = $UI
@onready var spawner      = $Spawner
@onready var chaser       = $Chaser

var _power_up_mgr_script := preload("res://scripts/PowerUpManager.gd")
var power_up_mgr = null

# ── Background palette refs ─────────────────────────────────
@onready var _pbg        : ParallaxBackground = $ParallaxBackground
@onready var _sky_spr    : Sprite2D = $ParallaxBackground/SkyLayer/Sprite2D
@onready var _far_spr    : Sprite2D = $ParallaxBackground/CityFarLayer/Sprite2D
@onready var _mid_spr    : Sprite2D = $ParallaxBackground/CityMidLayer/Sprite2D
@onready var _gnd_start  : Sprite2D = $StartGround/Sprite2D

var _night_shader : Shader = preload("res://assets/night_shift.gdshader")
## Cached ShaderMaterial per layer (created once, reused)
var _night_sky_mat   : ShaderMaterial
var _night_far_mat   : ShaderMaterial
var _night_mid_mat   : ShaderMaterial
var _night_gnd_mat   : ShaderMaterial
var _is_night        : bool = false

# ── Level definitions ───────────────────────────────────────
const LEVELS: Array[Dictionary] = [
	{
		"num":           1,
		"coins_goal":    50,
		"run_speed":     500.0,
		"spawn_rate":    0.72,
		"min_gap":       560.0,
		"max_gap":       1100.0,
		"diamonds_pool": 5,
		"close_speed":   260.0,
		"palette":       "neon_city",
		"sky_top":       Color(0.02, 0.02, 0.10),
		"sky_bot":       Color(0.04, 0.06, 0.18),
		"bld_colors":    [Color(0.06, 0.06, 0.14), Color(0.08, 0.08, 0.20), Color(0.04, 0.05, 0.12), Color(0.10, 0.08, 0.18)],
		"bld_win_color": Color(0.00, 0.92, 0.98, 0.6),
		"ground_color":  Color(0.0, 0.0, 0.0),
	},
	{
		"num":           2,
		"coins_goal":    50,
		"run_speed":     600.0,
		"spawn_rate":    0.85,
		"min_gap":       500.0,
		"max_gap":       850.0,
		"diamonds_pool": 9,
		"close_speed":   290.0,
		"palette":       "server_farm",
		"sky_top":       Color(0.05, 0.02, 0.14),
		"sky_bot":       Color(0.08, 0.03, 0.20),
		"bld_colors":    [Color(0.06, 0.03, 0.16), Color(0.10, 0.04, 0.22), Color(0.04, 0.02, 0.12), Color(0.08, 0.05, 0.18)],
		"bld_win_color": Color(0.48, 0.12, 1.00, 0.65),
		"ground_color":  Color(0.0, 0.0, 0.0),
	},
	{
		"num":           3,
		"coins_goal":    50,
		"run_speed":     648.0,       # +8 % over Level 2
		"spawn_rate":    0.90,
		"min_gap":       440.0,
		"max_gap":       720.0,
		"diamonds_pool": 12,
		"close_speed":   320.0,
		"palette":       "cyber_district",
		"sky_top":       Color(0.10, 0.02, 0.22),
		"sky_bot":       Color(0.24, 0.05, 0.32),
		"sun_color":     Color(1.00, 0.15, 0.60, 0.32),
		"bld_colors":    [Color(0.08, 0.06, 0.16),
						  Color(0.12, 0.08, 0.22),
						  Color(0.06, 0.04, 0.14),
						  Color(0.14, 0.10, 0.26)],
		"bld_win_color": Color(1.00, 0.15, 0.60, 0.75),
		"ground_color":  Color(0.0, 0.0, 0.0),
	},
	{
		"num":           4,
		"coins_goal":    50,
		"run_speed":     674.0,       # +4 % over Level 3
		"spawn_rate":    0.93,
		"min_gap":       400.0,
		"max_gap":       650.0,
		"diamonds_pool": 15,
		"close_speed":   350.0,
		"palette":       "digital_void",
		"sky_top":       Color(0.01, 0.02, 0.05),
		"sky_bot":       Color(0.02, 0.06, 0.10),
		"bld_colors":    [Color(0.04, 0.06, 0.08),
						  Color(0.06, 0.08, 0.12),
						  Color(0.03, 0.05, 0.07),
						  Color(0.05, 0.09, 0.11)],
		"bld_roof_colors": [Color(0.00, 0.85, 0.70),
							Color(0.10, 0.60, 0.50)],
		"bld_win_color": Color(0.00, 1.00, 0.65, 0.85),
		"hill_far":      Color(0.02, 0.15, 0.12),
		"hill_near":     Color(0.03, 0.24, 0.18),
		"tree_greens":   [Color(0.02, 0.30, 0.22), Color(0.03, 0.40, 0.28),
						  Color(0.02, 0.35, 0.20), Color(0.04, 0.45, 0.30)],
		"trunk_color":   Color(0.08, 0.12, 0.14),
		"ground_color":  Color(0.0, 0.0, 0.0),
		"grass_strip":   Color(0.00, 0.95, 0.75),
	},
]

# ── State ───────────────────────────────────────────────────
enum GameState { MENU, PLAYING, LEVEL_COMPLETE, GAME_OVER }
var game_state   : GameState = GameState.MENU
var current_level: int       = 0   # index into LEVELS

var coins_run    : int = 0   # collected this run / level
var diamonds_run : int = 0
var coin_wallet  : int = 0   # cumulative across levels
var score        : int = 0
var distance     : float = 0.0

const STARTING_LIVES : int = 3
var lives            : int = STARTING_LIVES

var chunk_x      : float = 0.0
const GROUND_Y   : float = 560.0

var ground_tex = preload("res://assets/ground.png")

# ── Boot ────────────────────────────────────────────────────
func _ready() -> void:
	print("[Main] _ready() — scene loaded OK")
	print("[Main] player=", player, "  ui=", ui, "  spawner=", spawner)
	get_tree().paused = true
	ui.start_pressed.connect(_on_start_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.next_level_pressed.connect(_on_next_level_pressed)
	ui.play_again_pressed.connect(_on_play_again_pressed)
	player.died.connect(_on_player_died)
	player.parkour_performed.connect(_on_parkour_performed)
	spawner.collectible_picked.connect(_on_collectible)
	chaser.caught.connect(_on_chaser_caught)
	for t in get_tree().get_nodes_in_group("water_towers"):
		register_water_tower(t)
	# Populate menu with Level 1 goals before player sees anything
	var d0 := LEVELS[0]
	ui.set_level_info(d0["num"], d0["coins_goal"])
	if _pbg:
		_pbg.scroll_ignore_camera_zoom = false

	# Generous sky coverage for Level 1 when camera zooms out to 0.75x
	_sky_spr.position = Vector2(-600.0, -350.0)
	_sky_spr.scale    = Vector2(3.0, 2.5)

	# Warm orange sky backdrop behind _sky_spr matching sky.png top gradient
	var sky_rect := ColorRect.new()
	sky_rect.name = "SkyBackdrop"
	sky_rect.position = Vector2(-2000.0, -1000.0)
	sky_rect.size = Vector2(8000.0, 2500.0)
	sky_rect.color = Color(0.902, 0.42, 0.25)
	sky_rect.z_index = -2
	$ParallaxBackground/SkyLayer.add_child(sky_rect)

	# Deep solid ground fill for Start Ground: 100% PURE BLACK below baseline
	var start_fill := ColorRect.new()
	start_fill.name = "StartFill"
	start_fill.size = Vector2(8000.0, 2500.0)
	start_fill.position = Vector2(0.0, 0.0)
	start_fill.color = Color(0.0, 0.0, 0.0, 1.0)
	start_fill.z_index = -1
	$StartGround.add_child(start_fill)

	# Neon Laser Curb for Start Ground
	var start_curb := ColorRect.new()
	start_curb.name = "StartCurb"
	start_curb.size = Vector2(8000.0, 3.0)
	start_curb.color = Color(0.00, 0.92, 0.98, 0.9)
	$StartGround.add_child(start_curb)

	# Algorithm Power-Up Manager
	power_up_mgr = _power_up_mgr_script.new()
	power_up_mgr.name = "PowerUpManager"
	power_up_mgr.player = player
	power_up_mgr.spawner = spawner
	power_up_mgr.camera = player.get_node_or_null("Camera2D") as Camera2D
	power_up_mgr.chaser = chaser
	add_child(power_up_mgr)

	print("[Main] ready — paused, signals wired")

## Registers a WaterTower to route coin pickups to _on_collectible.
func register_water_tower(tower: Node) -> void:
	if tower and tower.has_signal("collectible_picked"):
		if tower.get_parent() == spawner:
			return
		if not tower.collectible_picked.is_connected(_on_collectible):
			tower.collectible_picked.connect(_on_collectible)

# ── Level helpers ────────────────────────────────────────────
func _level_data() -> Dictionary:
	return LEVELS[current_level]

# Clears all dynamically spawned chunks and spawner children,
# then resets player + counters for the current level index.
func _reset_for_level() -> void:
	# 1. Free all ground chunks (tagged in _spawn_chunk)
	for n in get_tree().get_nodes_in_group("level_chunks"):
		n.queue_free()
	chunk_x = 0.0

	# 2. Free all obstacles / coins / diamonds inside Spawner
	for n in spawner.get_children():
		n.queue_free()
	spawner._next_x = 900.0

	# 3. Return player to start
	player.global_position = Vector2(300.0, 510.0)
	player.velocity        = Vector2.ZERO
	player.state           = "run"
	player.modulate        = Color(1, 1, 1)
	player.set_physics_process(true)
	if player.has_node("ColNormal"):
		(player.get_node("ColNormal") as CollisionShape2D).disabled = false
	if player.has_node("ColSlide"):
		(player.get_node("ColSlide") as CollisionShape2D).disabled = true
	if player.has_node("DustParticles"):
		(player.get_node("DustParticles") as CPUParticles2D).emitting = false
	if "stun_timer" in player:
		player.stun_timer = 0.0
	if player.has_method("reset_boost"):
		player.reset_boost()
	if player.has_method("flip_gravity"):
		player.flip_gravity(false)
	var cam = player.get_node_or_null("Camera2D")
	if cam and cam.has_method("set_gravity_flipped"):
		cam.set_gravity_flipped(false)
	if power_up_mgr:
		power_up_mgr.reset()

	# 4. Reset counters
	score    = 0
	distance = 0.0
	lives    = STARTING_LIVES

	# 5. Apply speed / spawn settings + reset per-level coin/diamond counts
	_apply_level()
	# 6. Reset chaser to FOLLOW_GAP behind the player's new start position
	chaser.reset(player)
	print("[Main] Level %d world reset complete" % _level_data()["num"])

func _apply_level() -> void:
	var d := _level_data()
	player.run_speed = d["run_speed"]
	chaser.CLOSE_SPEED = d.get("close_speed", 90.0)
	spawner.set_difficulty(
		d["spawn_rate"], d["min_gap"], d["max_gap"],
		d["diamonds_pool"], d["run_speed"], d["num"]
	)
	coins_run    = 0
	diamonds_run = 0
	_update_hud()
	_apply_palette(true)
	print("[Main] Level %d applied — speed=%.0f  spawn=%.2f" % [d["num"], d["run_speed"], d["spawn_rate"]])

# ── Level parallax layers & palettes ─────────────────────────
var _current_palette : String = "day"

## ParallaxLayers dynamically created once for Level 2, Level 3 and Level 4
var _lv2_layers      : Array[ParallaxLayer] = []
var _lv3_layers      : Array[ParallaxLayer] = []
var _lv4_layers      : Array[ParallaxLayer] = []
var _lv4_clouds      : Array = []   # [{node, speed}]
var _lv4_cloud_drift : bool  = false

func _apply_palette(force: bool = false) -> void:
	var d := _level_data()
	var pal : String = d.get("palette", "day")
	if not force and pal == _current_palette:
		return
	_current_palette = pal

	# Build procedural parallax layers once on demand
	if (pal == "server_farm" or pal == "night") and _lv2_layers.is_empty():
		_build_lv2_bg(d)
	elif (pal == "cyber_district" or pal == "bright_day") and _lv3_layers.is_empty():
		_build_lv3_bg(d)
	elif (pal == "digital_void" or pal == "nature") and _lv4_layers.is_empty():
		_build_lv4_bg(d)

	# Original parallax sprites ONLY visible for Level 1 (neon_city/day)
	var is_lvl1 : bool = (pal == "neon_city" or pal == "day")
	_sky_spr.visible = is_lvl1
	_far_spr.visible = is_lvl1
	_mid_spr.visible = is_lvl1

	# Toggle Level 2, Level 3 and Level 4 parallax layers
	for l in _lv2_layers:
		l.visible = (pal == "server_farm" or pal == "night")
	for l in _lv3_layers:
		l.visible = (pal == "cyber_district" or pal == "bright_day")
	for l in _lv4_layers:
		l.visible = (pal == "digital_void" or pal == "nature")

	_lv4_cloud_drift = (pal == "digital_void" or pal == "nature")

	# Reset sprites materials & apply level ground color
	_sky_spr.material   = null
	_far_spr.material   = null
	_mid_spr.material   = null
	_gnd_start.material = null
	_gnd_start.modulate = d.get("ground_color", Color(0.04, 0.04, 0.12))

	# Update StartFill deep ground background color
	# Update StartFill deep ground background color: 100% PURE BLACK
	var start_fill = $StartGround.get_node_or_null("StartFill")
	if start_fill:
		start_fill.color = Color(0.0, 0.0, 0.0, 1.0)

	# Update StartCurb laser edge color
	var start_curb = $StartGround.get_node_or_null("StartCurb")
	if start_curb:
		var curb_col : Color = Color(0.00, 0.92, 0.98, 0.9)
		if pal == "server_farm" or pal == "night":
			curb_col = Color(0.75, 0.20, 1.00, 0.95)
		elif pal == "cyber_district" or pal == "bright_day":
			curb_col = Color(1.00, 0.15, 0.65, 0.95)
		elif pal == "digital_void" or pal == "nature":
			curb_col = Color(0.00, 0.95, 0.75, 0.95)
		start_curb.color = curb_col

	# Update engine background clear color to 100% PURE BLACK
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))

	# Update Level 1 SkyBackdrop
	var sky_rect = get_node_or_null("ParallaxBackground/SkyLayer/SkyBackdrop")
	if sky_rect:
		sky_rect.color = d.get("sky_top", Color(0.902, 0.42, 0.25))

	if pal == "digital_void" or pal == "nature":
		if _lv4_clouds.size() > 0:
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for i in range(_lv4_clouds.size()):
				var n : Node2D = _lv4_clouds[i]["node"]
				var band : int = i % 3
				var y_pos : float = 40.0 + float(band) * 60.0 + rng.randf_range(-10.0, 15.0)
				n.position = Vector2(rng.randf_range(-80.0, 1360.0), y_pos)

# ── Level 2: Server Farm / Cyber Data Vault ──────────────────
func _build_lv2_bg(d: Dictionary) -> void:
	var sky_top : Color = d.get("sky_top", Color(0.04, 0.01, 0.12))
	var sky_bot : Color = d.get("sky_bot", Color(0.12, 0.03, 0.22))
	var bld_cols : Array = d.get("bld_colors", [Color(0.07, 0.03, 0.14), Color(0.10, 0.04, 0.20), Color(0.05, 0.02, 0.11), Color(0.09, 0.05, 0.17)])
	var win_col : Color = d.get("bld_win_color", Color(0.48, 0.12, 1.00, 0.65))

	# 1. Sky layer (motion_scale 0, 0)
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "Lv2Sky"
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	var sky_draw := _Lv2SkyDraw.new()
	sky_draw.c_top = sky_top
	sky_draw.c_bot = sky_bot
	sky_layer.add_child(sky_draw)
	_pbg.add_child(sky_layer)
	_lv2_layers.append(sky_layer)

	# 2. Far server monolith layer
	var far_layer := ParallaxLayer.new()
	far_layer.name = "Lv2ServerFar"
	far_layer.motion_scale = Vector2(0.12, 0.0)
	far_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var far_draw := _Lv2ServerDraw.new()
	far_draw.is_far       = true
	far_draw.rack_colors  = bld_cols
	far_draw.win_color    = win_col
	far_draw.server_seed  = 611
	far_draw.y_base       = 560.0
	far_draw.draw_width   = 1280.0
	far_layer.add_child(far_draw)
	_pbg.add_child(far_layer)
	_lv2_layers.append(far_layer)

	# 3. Near server rack layer
	var near_layer := ParallaxLayer.new()
	near_layer.name = "Lv2ServerNear"
	near_layer.motion_scale = Vector2(0.30, 0.0)
	near_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var near_draw := _Lv2ServerDraw.new()
	near_draw.is_far       = false
	near_draw.rack_colors  = bld_cols
	near_draw.win_color    = win_col
	near_draw.server_seed  = 722
	near_draw.y_base       = 560.0
	near_draw.draw_width   = 1280.0
	near_layer.add_child(near_draw)
	_pbg.add_child(near_layer)
	_lv2_layers.append(near_layer)

# ── Level 3: Bright daytime sky & city ───────────────────────
func _build_lv3_bg(d: Dictionary) -> void:
	var sky_top  : Color = d.get("sky_top",       Color(0.29, 0.66, 0.94))
	var sky_bot  : Color = d.get("sky_bot",       Color(0.87, 0.95, 1.00))
	var sun_col  : Color = d.get("sun_color",     Color(1.0, 0.97, 0.80, 0.18))
	var bld_cols : Array = d.get("bld_colors",    [Color(0.96, 0.96, 0.96), Color(0.84, 0.85, 0.88), Color(0.93, 0.89, 0.81), Color(0.80, 0.86, 0.92)])
	var win_col  : Color = d.get("bld_win_color", Color(0.72, 0.86, 0.98, 0.8))

	# 1. Sky layer (motion_scale 0, 0)
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "Lv3Sky"
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	var sky_draw := _Lv3SkyDraw.new()
	sky_draw.c_top = sky_top
	sky_draw.c_bot = sky_bot
	sky_draw.sun_color = sun_col
	sky_layer.add_child(sky_draw)
	_pbg.add_child(sky_layer)
	_lv3_layers.append(sky_layer)

	# 2. Far building layer (smaller, lighter, slower, hazier blue-white)
	var far_layer := ParallaxLayer.new()
	far_layer.name = "Lv3CityFar"
	far_layer.motion_scale = Vector2(0.10, 0.0)
	far_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var far_draw := _Lv3CityDraw.new()
	far_draw.is_far     = true
	far_draw.bld_colors = bld_cols
	far_draw.win_color  = win_col
	far_draw.city_seed  = 111
	far_draw.y_base     = 560.0
	far_draw.draw_width = 1280.0
	far_layer.add_child(far_draw)
	_pbg.add_child(far_layer)
	_lv3_layers.append(far_layer)

	# 3. Near building layer (larger, more detailed, slightly faster)
	var near_layer := ParallaxLayer.new()
	near_layer.name = "Lv3CityNear"
	near_layer.motion_scale = Vector2(0.28, 0.0)
	near_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var near_draw := _Lv3CityDraw.new()
	near_draw.is_far     = false
	near_draw.bld_colors = bld_cols
	near_draw.win_color  = win_col
	near_draw.city_seed  = 222
	near_draw.y_base     = 560.0
	near_draw.draw_width = 1280.0
	near_layer.add_child(near_draw)
	_pbg.add_child(near_layer)
	_lv3_layers.append(near_layer)

# ── Level 4: Nature with clouds, hills, town & trees ─────────
func _build_lv4_bg(d: Dictionary) -> void:
	var sky_top    : Color = d.get("sky_top",         Color(0.23, 0.61, 0.91))
	var sky_bot    : Color = d.get("sky_bot",         Color(0.81, 0.92, 1.00))
	var bld_cols   : Array = d.get("bld_colors",      [Color(0.96, 0.94, 0.86), Color(0.86, 0.56, 0.48), Color(0.68, 0.78, 0.68), Color(0.72, 0.82, 0.90)])
	var roof_cols  : Array = d.get("bld_roof_colors", [Color(0.74, 0.28, 0.22), Color(0.48, 0.32, 0.20)])
	var win_col    : Color = d.get("bld_win_color",   Color(0.74, 0.88, 0.98, 0.8))
	var hill_far   : Color = d.get("hill_far",        Color(0.55, 0.78, 0.42))
	var hill_near  : Color = d.get("hill_near",       Color(0.35, 0.62, 0.28))
	var tree_cols  : Array = d.get("tree_greens",     [Color(0.22, 0.55, 0.20), Color(0.30, 0.65, 0.25), Color(0.28, 0.58, 0.18), Color(0.38, 0.70, 0.30)])
	var trunk_col  : Color = d.get("trunk_color",     Color(0.40, 0.28, 0.15))

	# 1. Sky layer (motion_scale 0, 0)
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "Lv4Sky"
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	var sky_draw := _Lv4SkyDraw.new()
	sky_draw.c_top = sky_top
	sky_draw.c_bot = sky_bot
	sky_layer.add_child(sky_draw)
	_pbg.add_child(sky_layer)
	_lv4_layers.append(sky_layer)

	# 2. Clouds layer (many soft white clouds drifting slowly left in _process)
	var cloud_layer := ParallaxLayer.new()
	cloud_layer.name = "Lv4Clouds"
	cloud_layer.motion_scale = Vector2(0.0, 0.0)
	var cloud_root := Node2D.new()
	cloud_root.name = "CloudRoot"
	cloud_layer.add_child(cloud_root)
	_pbg.add_child(cloud_layer)
	_lv4_layers.append(cloud_layer)

	_lv4_clouds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(10):
		var cloud := _CloudDraw.new()
		cloud.cloud_seed = i * 7 + 3
		var band : int = i % 3
		var y_pos : float = 40.0 + float(band) * 60.0 + rng.randf_range(-10.0, 15.0)
		cloud.position = Vector2(rng.randf_range(-80.0, 1360.0), y_pos)
		var s : float = rng.randf_range(0.65, 0.85) if band == 0 else (rng.randf_range(0.85, 1.1) if band == 1 else rng.randf_range(1.15, 1.4))
		cloud.scale = Vector2(s, s * 0.72)
		var spd : float = rng.randf_range(8.0, 14.0) if band == 0 else (rng.randf_range(14.0, 20.0) if band == 1 else rng.randf_range(20.0, 28.0))
		cloud_root.add_child(cloud)
		_lv4_clouds.append({"node": cloud, "speed": spd})

	# 3. Rolling green hills (far & near) - behind the far buildings
	var hill_far_layer := ParallaxLayer.new()
	hill_far_layer.name = "Lv4HillFar"
	hill_far_layer.motion_scale = Vector2(0.06, 0.0)
	hill_far_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var hf_draw := _HillDraw.new()
	hf_draw.hill_color = hill_far
	hf_draw.hill_seed  = 333
	hf_draw.y_base     = 560.0
	hf_draw.amplitude  = 65.0
	hf_draw.draw_width = 1280.0
	hf_draw.y_offset   = -45.0
	hill_far_layer.add_child(hf_draw)
	_pbg.add_child(hill_far_layer)
	_lv4_layers.append(hill_far_layer)

	var hill_near_layer := ParallaxLayer.new()
	hill_near_layer.name = "Lv4HillNear"
	hill_near_layer.motion_scale = Vector2(0.10, 0.0)
	hill_near_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var hn_draw := _HillDraw.new()
	hn_draw.hill_color = hill_near
	hn_draw.hill_seed  = 444
	hn_draw.y_base     = 560.0
	hn_draw.amplitude  = 50.0
	hn_draw.draw_width = 1280.0
	hn_draw.y_offset   = -10.0
	hill_near_layer.add_child(hn_draw)
	_pbg.add_child(hill_near_layer)
	_lv4_layers.append(hill_near_layer)

	# 4. Small-town far buildings layer (smaller, lighter, slower)
	var town_far_layer := ParallaxLayer.new()
	town_far_layer.name = "Lv4TownFar"
	town_far_layer.motion_scale = Vector2(0.16, 0.0)
	town_far_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var tf_draw := _Lv4TownDraw.new()
	tf_draw.is_far      = true
	tf_draw.bld_colors  = bld_cols
	tf_draw.roof_colors = roof_cols
	tf_draw.tree_colors = tree_cols
	tf_draw.trunk_color = trunk_col
	tf_draw.win_color   = win_col
	tf_draw.town_seed   = 555
	tf_draw.y_base      = 560.0
	tf_draw.draw_width  = 1280.0
	town_far_layer.add_child(tf_draw)
	_pbg.add_child(town_far_layer)
	_lv4_layers.append(town_far_layer)

	# 5. Small-town near buildings layer (larger, more detailed, 3-5 floors, sloped roofs & trees)
	var town_near_layer := ParallaxLayer.new()
	town_near_layer.name = "Lv4TownNear"
	town_near_layer.motion_scale = Vector2(0.26, 0.0)
	town_near_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var tn_draw := _Lv4TownDraw.new()
	tn_draw.is_far      = false
	tn_draw.bld_colors  = bld_cols
	tn_draw.roof_colors = roof_cols
	tn_draw.tree_colors = tree_cols
	tn_draw.trunk_color = trunk_col
	tn_draw.win_color   = win_col
	tn_draw.town_seed   = 666
	tn_draw.y_base      = 560.0
	tn_draw.draw_width  = 1280.0
	town_near_layer.add_child(tn_draw)
	_pbg.add_child(town_near_layer)
	_lv4_layers.append(town_near_layer)

	# 6. Front trees & greenery band (in front of buildings)
	var tree_layer := ParallaxLayer.new()
	tree_layer.name = "Lv4TreesFront"
	tree_layer.motion_scale = Vector2(0.34, 0.0)
	tree_layer.motion_mirroring = Vector2(1280.0, 0.0)
	var tree_draw := _TreeBandDraw.new()
	tree_draw.tree_colors = tree_cols
	tree_draw.trunk_color = trunk_col
	tree_draw.tree_seed   = 777
	tree_draw.y_base      = 560.0
	tree_draw.draw_width  = 1280.0
	tree_layer.add_child(tree_draw)
	_pbg.add_child(tree_layer)
	_lv4_layers.append(tree_layer)


func _check_goals() -> void:
	var d := _level_data()
	if coins_run >= d["coins_goal"]:
		_complete_level()

func _complete_level() -> void:
	game_state = GameState.LEVEL_COMPLETE
	get_tree().paused = true
	chaser.deactivate()
	var d := _level_data()
	if current_level + 1 >= LEVELS.size():
		# Last level finished → You Win
		coin_wallet += coins_run
		ui.show_you_win()
	else:
		coin_wallet += coins_run
		ui.show_level_complete(d["num"], coins_run, diamonds_run)

# ── Signal handlers ──────────────────────────────────────────
func _on_start_pressed() -> void:
	# current_level is already 0 on fresh load, or 1+ set by _on_next_level_pressed.
	# Do NOT reset it here so level transitions work correctly.
	game_state = GameState.PLAYING
	get_tree().paused = false
	ui.hide_all()
	_reset_for_level()

func _on_next_level_pressed() -> void:
	current_level += 1
	# Show the next level start screen (paused) then wait for Start press
	var d := _level_data()
	ui.set_level_info(d["num"], d["coins_goal"])
	ui.show_menu()
	# World reset happens in _on_start_pressed → _reset_for_level, so no work here

func _on_restart_pressed() -> void:
	_reset_for_level()
	var d := _level_data()
	ui.set_level_info(d["num"], d["coins_goal"])
	ui.show_menu()

func _on_play_again_pressed() -> void:
	current_level = 0
	_reset_for_level()
	var d := _level_data()
	ui.set_level_info(d["num"], d["coins_goal"])
	ui.show_menu()

func _on_player_died() -> void:
	if game_state == GameState.GAME_OVER:
		return   # guard: chaser may also call game over on the same frame
	lives = 0
	game_state = GameState.GAME_OVER
	get_tree().paused = true
	chaser.deactivate()
	ui.show_gameover(score, int(distance))

func _on_chaser_caught() -> void:
	# Chaser reached the player — end the run immediately (guard against double trigger)
	if game_state != GameState.PLAYING:
		return
	_on_player_died()

func _on_parkour_performed(trick_name: String, bonus_score: int) -> void:
	score += bonus_score
	show_popup("+%d %s" % [bonus_score, trick_name], player.global_position)

func _on_collectible(kind: int) -> void:
	if kind == Collectible.Type.COIN:
		coins_run  += 1
		coin_wallet += 1
		sfx_coin.play()
	else:
		diamonds_run += 1
	score += 10 if kind == Collectible.Type.COIN else 50
	_update_hud()
	_check_goals()

func _update_hud() -> void:
	var d := _level_data()
	hud_coins.text    = "Coins: %d / %d" % [coins_run, d["coins_goal"]]
	hud_diamonds.text = "Diamonds: %d" % diamonds_run

# ── Ground chunk spawner ─────────────────────────────────────
func _process(delta: float) -> void:
	if not player or game_state == GameState.GAME_OVER or game_state == GameState.LEVEL_COMPLETE:
		return
	distance       = player.global_position.x / 100.0
	hud_score.text = "Lv%d  Dist: %dm  Score: %d" % [_level_data()["num"], int(distance), score]
	if player.global_position.x + 1500.0 > chunk_x:
		_spawn_chunk()

	# Level 4 cloud drift
	if _lv4_cloud_drift:
		for info in _lv4_clouds:
			var n : Node2D = info["node"]
			n.position.x -= info["speed"] * delta
			if n.position.x < -200.0:
				n.position.x = 1450.0

func _spawn_chunk() -> void:
	var root := Node2D.new()
	root.position = Vector2(chunk_x, 0.0)
	root.add_to_group("level_chunks")   # tagged so _reset_for_level can clear them
	add_child(root)

	# StaticBody sits AT the ground top surface
	var gb := StaticBody2D.new()
	gb.position = Vector2(0.0, GROUND_Y)
	root.add_child(gb)

	var d := _level_data()
	var g_color : Color = d.get("ground_color", Color(0.0, 0.0, 0.0))

	# Deep solid ground fill extending downwards 2500px: 100% PURE BLACK below baseline
	var g_fill := ColorRect.new()
	g_fill.color = Color(0.0, 0.0, 0.0, 1.0)
	g_fill.size = Vector2(1000.0, 2500.0)
	g_fill.position = Vector2(0.0, 0.0)
	g_fill.z_index = -1
	gb.add_child(g_fill)

	# Sprite: centered=false → top-left is at gb.position = GROUND_Y (visual top = GROUND_Y)
	var g_spr := Sprite2D.new()
	g_spr.texture  = ground_tex
	g_spr.centered = false
	g_spr.position = Vector2(0.0, 0.0)   # top-left at GROUND_Y, extends 200 px down
	g_spr.scale    = Vector2(2.0, 1.0)   # 1000 px wide, 200 px tall
	g_spr.modulate = g_color
	gb.add_child(g_spr)

	# Glowing Cyber Neon Laser Curb across all levels
	var curb := ColorRect.new()
	var curb_col : Color = Color(0.00, 0.92, 0.98, 0.9)
	if _current_palette == "server_farm" or _current_palette == "night":
		curb_col = Color(0.75, 0.20, 1.00, 0.95)
	elif _current_palette == "cyber_district" or _current_palette == "bright_day":
		curb_col = Color(1.00, 0.15, 0.65, 0.95)
	elif _current_palette == "digital_void" or _current_palette == "nature":
		curb_col = Color(0.00, 0.95, 0.75, 0.95)
	curb.color = curb_col
	curb.size = Vector2(1000.0, 3.0)
	curb.position = Vector2(0.0, 0.0)
	gb.add_child(curb)

	# Collision: size matches full texture height so top = GROUND_Y (center at +100)
	var g_col := CollisionShape2D.new()
	var g_shp := RectangleShape2D.new()
	g_shp.size     = Vector2(1000.0, 200.0)
	g_col.shape    = g_shp
	g_col.position = Vector2(500.0, 100.0)  # center 100 px below GROUND_Y → top at GROUND_Y
	gb.add_child(g_col)

	chunk_x += 1000.0

func show_popup(text_str: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.global_position = pos + Vector2(-20.0, -50.0)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0))
	lbl.add_theme_font_size_override("font_size", 24)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100.0, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

# ══════════════════════════════════════════════════════════════
# Inner helper classes for procedural backgrounds (drawn once)
# ══════════════════════════════════════════════════════════════

## Level 2 Server Farm / Data Vault sky: deep obsidian-violet with cascading data streams
class _Lv2SkyDraw extends Node2D:
	var c_top : Color = Color(0.04, 0.01, 0.12)
	var c_bot : Color = Color(0.12, 0.03, 0.22)

	func _draw() -> void:
		var w : float = 2560.0
		var y_start : float = -400.0
		var total_h : float = 2000.0
		var steps : int = 40
		var sh : float = total_h / float(steps)
		for i in range(steps):
			var t : float = float(i) / float(steps)
			var col : Color = c_top.lerp(c_bot, t)
			draw_rect(Rect2(0.0, y_start + sh * float(i), w, sh + 1.5), col)

		# Cascading vertical server data streams (purple and amber trace lines)
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		for i in range(36):
			var stream_x : float = rng.randf_range(10.0, w - 10.0)
			var stream_y : float = rng.randf_range(-100.0, 700.0)
			var stream_len : float = rng.randf_range(60.0, 180.0)
			var is_amber : bool = (i % 4 == 0)
			var stream_col : Color = Color(1.00, 0.65, 0.10, 0.15) if is_amber else Color(0.65, 0.15, 1.00, 0.18)
			draw_line(Vector2(stream_x, stream_y), Vector2(stream_x, stream_y + stream_len), stream_col, 1.2)
			draw_circle(Vector2(stream_x, stream_y + stream_len), 1.5, Color(stream_col.r, stream_col.g, stream_col.b, 0.4))

## Level 2 Server Farm mainframe racks with glowing LED arrays, cooling vents, and bus-bars
class _Lv2ServerDraw extends Node2D:
	var is_far       : bool  = false
	var rack_colors  : Array = [Color(0.07, 0.03, 0.14), Color(0.10, 0.04, 0.20), Color(0.05, 0.02, 0.11), Color(0.09, 0.05, 0.17)]
	var win_color    : Color = Color(0.48, 0.12, 1.00, 0.65)
	var server_seed  : int   = 202
	var y_base       : float = 560.0
	var draw_width   : float = 1280.0
	var skirt_h      : float = 900.0   # Solid base down to Y = 1460

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = server_seed
		var cx : float = 0.0

		while cx < draw_width:
			var bw : float = rng.randf_range(50.0, 85.0) if is_far else rng.randf_range(65.0, 115.0)
			var bh : float = rng.randf_range(140.0, 260.0) if is_far else rng.randf_range(200.0, 360.0)
			var by : float = y_base - bh

			var base_col : Color = rack_colors[rng.randi() % rack_colors.size()]
			if is_far:
				base_col = base_col.lerp(Color(0.14, 0.06, 0.26), 0.35)

			var main_w : float = bw * 0.82
			var shade_w : float = bw - main_w
			var shade_col : Color = base_col.darkened(0.15)

			# Server rack body + deep skirt all the way down past ground
			draw_rect(Rect2(cx, by, main_w, bh + skirt_h), base_col)
			draw_rect(Rect2(cx + main_w, by, shade_w, bh + skirt_h), shade_col)

			# Tech outline
			var outline_col := Color(0.65, 0.20, 1.00, 0.20 if is_far else 0.35)
			draw_rect(Rect2(cx, by, bw, bh + skirt_h), outline_col, false, 1.0)
			draw_line(Vector2(cx + main_w, by), Vector2(cx + main_w, y_base + skirt_h), outline_col, 1.0)

			# Server top details: heat exhaust vents / optical antenna
			var top_feature : int = rng.randi() % 3
			match top_feature:
				1: # Server cooling vent hood
					var v_w : float = bw * 0.6
					var v_h : float = 10.0
					var v_x : float = cx + bw * 0.2
					draw_rect(Rect2(v_x, by - v_h, v_w, v_h), base_col.darkened(0.2))
					draw_rect(Rect2(v_x, by - v_h, v_w, v_h), outline_col, false, 1.0)
					for f in range(3):
						var fx : float = v_x + 3.0 + float(f) * (v_w - 6.0) / 2.0
						draw_line(Vector2(fx, by - v_h + 2.0), Vector2(fx, by - 2.0), Color(0.8, 0.3, 1.0, 0.4), 1.0)
				2: # High-speed fiber optical beacon
					var ant_x : float = cx + bw * 0.5
					var ant_h : float = rng.randf_range(16.0, 28.0)
					draw_line(Vector2(ant_x, by), Vector2(ant_x, by - ant_h), Color(0.7, 0.3, 1.0, 0.6), 1.5)
					draw_circle(Vector2(ant_x, by - ant_h), 2.0, Color(1.0, 0.65, 0.1, 0.85))

			# Server rack blades & LED activity lights
			var blade_h : float = 12.0 if is_far else 16.0
			var blade_gap : float = 4.0 if is_far else 6.0
			var cur_y : float = by + 10.0
			while cur_y + blade_h < y_base:
				# Server blade faceplate
				draw_rect(Rect2(cx + 4.0, cur_y, main_w - 8.0, blade_h), base_col.lightened(0.04))
				draw_rect(Rect2(cx + 4.0, cur_y, main_w - 8.0, blade_h), Color(0.5, 0.15, 0.8, 0.15), false, 1.0)

				# Row of LED status lights on each blade
				var num_leds : int = 2 if is_far else 4
				for li in range(num_leds):
					var led_x : float = cx + 8.0 + float(li) * 7.0
					var led_y : float = cur_y + blade_h * 0.5
					var led_col : Color
					var r_led : int = (li + int(cur_y)) % 5
					match r_led:
						0: led_col = Color(0.20, 1.00, 0.40, 0.85)  # Green active
						1: led_col = Color(1.00, 0.65, 0.10, 0.85)  # Amber warning
						2: led_col = Color(0.85, 0.25, 1.00, 0.90)  # Violet processing
						_: led_col = Color(0.00, 0.90, 0.95, 0.75)  # Cyan network
					draw_circle(Vector2(led_x, led_y), 1.2 if is_far else 1.8, led_col)

				# Vent grille on right side of blade
				if not is_far and main_w > 50.0:
					var vent_x : float = cx + main_w - 20.0
					draw_line(Vector2(vent_x, cur_y + 4.0), Vector2(vent_x + 12.0, cur_y + 4.0), Color(0.0, 0.0, 0.0, 0.5), 1.0)
					draw_line(Vector2(vent_x, cur_y + blade_h - 4.0), Vector2(vent_x + 12.0, cur_y + blade_h - 4.0), Color(0.0, 0.0, 0.0, 0.5), 1.0)

				cur_y += blade_h + blade_gap

			# Vertical illuminated bus conduit on side
			var bus_x : float = cx + bw - 3.0
			draw_line(Vector2(bus_x, by), Vector2(bus_x, y_base + skirt_h), Color(0.70, 0.15, 1.00, 0.45), 1.5)

			cx += bw + rng.randf_range(3.0, 8.0)

## Level 3 daytime sky gradient, sun glow, and faint wisps (extends Y = -300 to 1100)
class _Lv3SkyDraw extends Node2D:
	var c_top     : Color = Color(0.29, 0.66, 0.94)
	var c_bot     : Color = Color(0.87, 0.95, 1.00)
	var sun_color : Color = Color(1.0, 0.97, 0.80, 0.18)

	func _draw() -> void:
		var w : float = 2560.0
		var y_start : float = -400.0
		var total_h : float = 2000.0
		var steps : int = 40
		var sh : float = total_h / float(steps)
		for i in range(steps):
			var t : float = float(i) / float(steps)
			var col : Color = c_top.lerp(c_bot, t)
			draw_rect(Rect2(0.0, y_start + sh * float(i), w, sh + 1.5), col)
		# Soft pale-yellow sun glow in upper area
		if sun_color.a > 0.01:
			var cx : float = w * 0.75
			var cy : float = 100.0
			for r in range(3):
				var radius : float = 60.0 + float(r) * 40.0
				var a : float = sun_color.a * (1.0 - float(r) * 0.3)
				draw_circle(Vector2(cx, cy), radius, Color(sun_color.r, sun_color.g, sun_color.b, a))
		# 2-3 very faint wisps in the sky
		var wisps := [Vector2(180.0, 75.0), Vector2(480.0, 115.0), Vector2(880.0, 55.0)]
		for wisp in wisps:
			draw_line(wisp, wisp + Vector2(80.0, -5.0), Color(1.0, 1.0, 1.0, 0.08), 12.0, true)
			draw_line(wisp + Vector2(10.0, 4.0), wisp + Vector2(70.0, 0.0), Color(1.0, 1.0, 1.0, 0.05), 8.0, true)

## Level 3 bright daytime city buildings (far & near layers)
class _Lv3CityDraw extends Node2D:
	var is_far     : bool  = false
	var bld_colors : Array = [Color(0.96, 0.96, 0.96), Color(0.84, 0.85, 0.88), Color(0.93, 0.89, 0.81), Color(0.80, 0.86, 0.92)]
	var win_color  : Color = Color(0.72, 0.86, 0.98, 0.8)
	var city_seed  : int   = 111
	var y_base     : float = 560.0
	var draw_width : float = 1280.0
	var skirt_h    : float = 900.0   # Solid base down to Y = 1460

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = city_seed
		var cx : float = 0.0

		while cx < draw_width:
			var bw : float = rng.randf_range(42.0, 75.0) if is_far else rng.randf_range(55.0, 105.0)
			var bh : float = rng.randf_range(110.0, 230.0) if is_far else rng.randf_range(160.0, 330.0)
			var by : float = y_base - bh

			var base_col : Color = bld_colors[rng.randi() % bld_colors.size()]
			if is_far:
				base_col = base_col.lerp(Color(0.86, 0.93, 1.0), 0.42)

			# Soft darker shade on one side (right side, ~22% width) for depth
			var main_w : float = bw * 0.78
			var shade_w : float = bw - main_w
			var shade_col : Color = base_col.darkened(0.12 if not is_far else 0.08)

			draw_rect(Rect2(cx, by, main_w, bh + skirt_h), base_col)
			draw_rect(Rect2(cx + main_w, by, shade_w, bh + skirt_h), shade_col)

			# Subtle outline for architectural structure
			var outline_col := Color(0.55, 0.62, 0.70, 0.25 if is_far else 0.35)
			draw_rect(Rect2(cx, by, bw, bh + skirt_h), outline_col, false, 1.0)
			draw_line(Vector2(cx + main_w, by), Vector2(cx + main_w, y_base + skirt_h), outline_col, 1.0)

			# Flat roofs with small details (antennas, water tanks, rooftop boxes)
			var roof_feature : int = rng.randi() % 4
			match roof_feature:
				1: # Rooftop box / elevator shaft
					var box_w : float = rng.randf_range(12.0, 26.0)
					var box_h : float = rng.randf_range(8.0, 16.0)
					var box_x : float = cx + rng.randf_range(4.0, maxf(4.0, main_w - box_w - 4.0))
					draw_rect(Rect2(box_x, by - box_h, box_w, box_h), base_col.darkened(0.15))
					draw_rect(Rect2(box_x, by - box_h, box_w, box_h), outline_col, false, 1.0)
				2: # Antenna
					var ant_x : float = cx + rng.randf_range(8.0, bw - 8.0)
					var ant_h : float = rng.randf_range(15.0, 30.0)
					draw_line(Vector2(ant_x, by), Vector2(ant_x, by - ant_h), Color(0.40, 0.45, 0.52, 0.7), 1.5)
					draw_circle(Vector2(ant_x, by - ant_h), 1.8, Color(0.9, 0.3, 0.25, 0.85))
				3: # Water tank on legs
					var tank_x : float = cx + rng.randf_range(6.0, maxf(6.0, bw - 22.0))
					var tank_w : float = 14.0
					var tank_h : float = 11.0
					draw_rect(Rect2(tank_x, by - tank_h - 4.0, tank_w, tank_h), Color(0.52, 0.50, 0.46, 0.9))
					draw_line(Vector2(tank_x + 3.0, by - 4.0), Vector2(tank_x + 3.0, by), Color(0.35, 0.35, 0.35, 0.8), 1.5)
					draw_line(Vector2(tank_x + tank_w - 3.0, by - 4.0), Vector2(tank_x + tank_w - 3.0, by), Color(0.35, 0.35, 0.35, 0.8), 1.5)

			# Windows arranged in grids
			var w_col : Color = win_color
			if is_far:
				w_col = win_color.lerp(Color(0.88, 0.94, 1.0), 0.35)
				w_col.a = 0.65

			var win_w : float = 6.0 if is_far else 8.0
			var win_h : float = 7.0 if is_far else 10.0
			var step_x : float = win_w + (5.0 if is_far else 7.0)
			var step_y : float = win_h + (6.0 if is_far else 9.0)

			var start_y : float = by + (10.0 if is_far else 14.0)
			var cur_y : float = start_y
			while cur_y + win_h < y_base - 10.0:
				var cur_x : float = cx + 5.0
				while cur_x + win_w < cx + main_w - 3.0:
					draw_rect(Rect2(cur_x, cur_y, win_w, win_h), w_col)
					cur_x += step_x
				cur_y += step_y

			cx += bw + rng.randf_range(2.0, 6.0)

## Level 4 sky gradient (extends Y = -300 to 1100)
class _Lv4SkyDraw extends Node2D:
	var c_top : Color = Color(0.23, 0.61, 0.91)
	var c_bot : Color = Color(0.81, 0.92, 1.00)

	func _draw() -> void:
		var w : float = 2560.0
		var y_start : float = -400.0
		var total_h : float = 2000.0
		var steps : int = 40
		var sh : float = total_h / float(steps)
		for i in range(steps):
			var t : float = float(i) / float(steps)
			var col : Color = c_top.lerp(c_bot, t)
			draw_rect(Rect2(0.0, y_start + sh * float(i), w, sh + 1.5), col)

## Single cloud built from overlapping circles/ellipses
class _CloudDraw extends Node2D:
	var cloud_seed : int   = 0
	var col        : Color = Color(1.0, 1.0, 1.0, 0.88)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = cloud_seed
		var circles : int = rng.randi_range(5, 8)
		for i in range(circles):
			var cx : float = rng.randf_range(15.0, 95.0)
			var cy : float = rng.randf_range(10.0, 35.0)
			var rx : float = rng.randf_range(18.0, 32.0)
			draw_circle(Vector2(cx, cy), rx, col)

## Rolling green hill (Node2D) extending solid down to Y = 1460
class _HillDraw extends Node2D:
	var hill_color : Color = Color(0.55, 0.78, 0.42)
	var hill_seed  : int   = 333
	var y_base     : float = 560.0
	var amplitude  : float = 80.0
	var draw_width : float = 1280.0
	var y_offset   : float = 0.0
	var skirt_h    : float = 900.0

	func _draw() -> void:
		var pts : PackedVector2Array = PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = hill_seed
		var freq1 : float = rng.randf_range(0.003, 0.006)
		var freq2 : float = rng.randf_range(0.008, 0.014)
		var phase : float = rng.randf_range(0.0, TAU)
		var steps : int = 64
		var dx : float = draw_width / float(steps)
		for i in range(steps + 1):
			var x : float = dx * float(i)
			var y : float = y_base + y_offset - amplitude * (
				sin(x * freq1 + phase) * 0.6 + sin(x * freq2 + phase * 1.7) * 0.4
			)
			pts.append(Vector2(x, y))
		pts.append(Vector2(draw_width, y_base + skirt_h))
		pts.append(Vector2(0.0, y_base + skirt_h))
		draw_colored_polygon(pts, hill_color)

## Level 4 small-town / garden city buildings with sloped roofs and trees
class _Lv4TownDraw extends Node2D:
	var is_far       : bool  = false
	var bld_colors   : Array = [Color(0.96, 0.94, 0.86), Color(0.86, 0.56, 0.48), Color(0.68, 0.78, 0.68), Color(0.72, 0.82, 0.90)]
	var roof_colors  : Array = [Color(0.74, 0.28, 0.22), Color(0.48, 0.32, 0.20)]
	var tree_colors  : Array = [Color(0.22, 0.55, 0.20), Color(0.30, 0.65, 0.25)]
	var trunk_color  : Color = Color(0.40, 0.28, 0.15)
	var win_color    : Color = Color(0.74, 0.88, 0.98, 0.8)
	var town_seed    : int   = 333
	var y_base       : float = 560.0
	var draw_width   : float = 1280.0
	var skirt_h      : float = 900.0   # Solid base down to Y = 1460

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = town_seed
		var cx : float = 10.0

		while cx < draw_width:
			# Trees and bushes between buildings
			var gap_w : float = rng.randf_range(20.0, 45.0) if is_far else rng.randf_range(30.0, 65.0)
			_draw_tree_cluster(cx, gap_w, rng)
			cx += gap_w
			if cx >= draw_width:
				break

			# 3-5 floors: lower and fewer than in Level 3
			var bw : float = rng.randf_range(42.0, 70.0) if is_far else rng.randf_range(58.0, 92.0)
			var floors : int = rng.randi_range(3, 4) if is_far else rng.randi_range(3, 5)
			var floor_h : float = 20.0 if is_far else 26.0
			var bh : float = float(floors) * floor_h + 10.0
			var by : float = y_base - bh

			var base_col : Color = bld_colors[rng.randi() % bld_colors.size()]
			if is_far:
				base_col = base_col.lerp(Color(0.85, 0.92, 0.90), 0.35)

			var main_w : float = bw * 0.80
			var shade_w : float = bw - main_w
			var shade_col : Color = base_col.darkened(0.12)

			# Building body & solid skirt all the way down
			draw_rect(Rect2(cx, by, main_w, bh + skirt_h), base_col)
			draw_rect(Rect2(cx + main_w, by, shade_w, bh + skirt_h), shade_col)

			var outline_col := Color(0.45, 0.45, 0.45, 0.25 if is_far else 0.35)
			draw_rect(Rect2(cx, by, bw, bh + skirt_h), outline_col, false, 1.0)

			# Roof: some with sloped red or brown roofs, some with flat/cornice
			var has_sloped_roof : bool = (rng.randf() < 0.65)
			if has_sloped_roof:
				var r_col : Color = roof_colors[rng.randi() % roof_colors.size()]
				if is_far:
					r_col = r_col.lerp(Color(0.85, 0.92, 0.90), 0.30)
				var roof_h : float = rng.randf_range(16.0, 24.0) if is_far else rng.randf_range(20.0, 32.0)
				var ov : float = 4.0
				var p_left := Vector2(cx - ov, by)
				var p_right := Vector2(cx + bw + ov, by)
				var p_peak := Vector2(cx + bw * 0.5, by - roof_h)
				var tri_pts := PackedVector2Array([p_left, p_right, p_peak])
				draw_colored_polygon(tri_pts, r_col)
				# Darker shaded right side of roof
				var shade_roof_pts := PackedVector2Array([p_peak, p_right, Vector2(cx + bw * 0.5, by)])
				draw_colored_polygon(shade_roof_pts, r_col.darkened(0.15))
				draw_line(p_left, p_peak, outline_col, 1.5)
				draw_line(p_peak, p_right, outline_col, 1.5)
				draw_line(p_left, p_right, outline_col, 1.0)
				if rng.randf() < 0.45:
					var ch_x : float = cx + bw * 0.25
					var ch_h : float = 8.0
					draw_rect(Rect2(ch_x, by - roof_h * 0.5 - ch_h, 5.0, ch_h + 4.0), r_col.darkened(0.2))
			else:
				var cornice_col : Color = base_col.darkened(0.15)
				draw_rect(Rect2(cx - 2.0, by - 4.0, bw + 4.0, 5.0), cornice_col)

			# Windows in light blue (arranged by floors)
			var w_col : Color = win_color
			if is_far:
				w_col = win_color.lerp(Color(0.85, 0.92, 0.98), 0.3)
				w_col.a = 0.70

			var win_w : float = 6.0 if is_far else 8.0
			var win_h : float = 8.0 if is_far else 11.0
			for fl in range(floors):
				var fl_y : float = by + 12.0 + float(fl) * floor_h
				if fl_y + win_h >= y_base - 10.0:
					break
				var num_win : int = 2 if bw < 60.0 else 3
				var step : float = main_w / float(num_win + 1)
				for wi in range(num_win):
					var wx : float = cx + step * float(wi + 1) - win_w * 0.5
					draw_rect(Rect2(wx, fl_y, win_w, win_h), w_col)
					draw_rect(Rect2(wx - 1.0, fl_y + win_h, win_w + 2.0, 1.5), Color(0.95, 0.95, 0.95, 0.7))

			# Trees / bushes placed in front of building base
			if not is_far and rng.randf() < 0.65:
				var bush_x : float = cx + rng.randf_range(4.0, bw - 15.0)
				var bush_r : float = rng.randf_range(8.0, 14.0)
				var b_col : Color = tree_colors[rng.randi() % tree_colors.size()]
				draw_circle(Vector2(bush_x, y_base - bush_r * 0.5), bush_r, b_col)

			cx += bw

	func _draw_tree_cluster(x_start: float, span_w: float, rng: RandomNumberGenerator) -> void:
		var num_trees : int = 1 if span_w < 35.0 else 2
		for t in range(num_trees):
			var tx : float = x_start + span_w * (float(t + 1) / float(num_trees + 1))
			var t_h : float = rng.randf_range(25.0, 48.0) if is_far else rng.randf_range(40.0, 70.0)
			var t_r : float = rng.randf_range(12.0, 20.0) if is_far else rng.randf_range(18.0, 32.0)
			var green : Color = tree_colors[rng.randi() % tree_colors.size()]
			var tw : float = 4.0 if is_far else 6.0
			draw_rect(Rect2(tx - tw * 0.5, y_base - t_h, tw, t_h + skirt_h), trunk_color)
			var top_y : float = y_base - t_h
			draw_circle(Vector2(tx, top_y), t_r, green)
			draw_circle(Vector2(tx - t_r * 0.35, top_y + 3.0), t_r * 0.75, green.darkened(0.10))
			draw_circle(Vector2(tx + t_r * 0.35, top_y + 2.0), t_r * 0.70, green.lightened(0.08))

## Tree band (Node2D) — rounded canopy trees
class _TreeBandDraw extends Node2D:
	var tree_colors : Array = [Color(0.25, 0.55, 0.20)]
	var trunk_color : Color = Color(0.40, 0.28, 0.15)
	var tree_seed   : int   = 555
	var y_base      : float = 560.0
	var draw_width  : float = 1280.0
	var skirt_h     : float = 900.0   # Solid base down to Y = 1460

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = tree_seed
		var tx : float = 20.0
		while tx < draw_width:
			var trunk_h : float = rng.randf_range(40.0, 70.0)
			var trunk_w : float = rng.randf_range(6.0, 10.0)
			var canopy_r: float = rng.randf_range(20.0, 38.0)
			var green   : Color = tree_colors[rng.randi() % tree_colors.size()]
			var base_y  : float = y_base
			draw_rect(Rect2(tx - trunk_w * 0.5, base_y - trunk_h, trunk_w, trunk_h + skirt_h), trunk_color)
			var top_y : float = base_y - trunk_h
			draw_circle(Vector2(tx, top_y), canopy_r, green)
			draw_circle(Vector2(tx - canopy_r * 0.5, top_y + 5.0), canopy_r * 0.8, green.darkened(0.1))
			draw_circle(Vector2(tx + canopy_r * 0.4, top_y + 3.0), canopy_r * 0.7, green.lightened(0.08))
			tx += rng.randf_range(60.0, 120.0)
