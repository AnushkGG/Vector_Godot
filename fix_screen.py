import os

scripts = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector\scripts"

level_gd = """# Vector Runner - Level Manager
extends Node2D

@onready var player     = $Player
@onready var hud_score  = $CanvasLayer/HUD/Score
@onready var sfx_coin   = $SfxCoin

var chunk_x  = 0.0       # start spawning right from the beginning
var score    = 0
var distance = 0.0
var chunks   = []        # track all chunk roots so we can clean up old ones

var ground_tex = preload("res://assets/ground.png")
var coin_tex   = preload("res://assets/coin.png")

var obs_types = [
    ["res://assets/obs_watertank.png",  50,  80,  false],
    ["res://assets/obs_crane.png",     120,  90,  false],
    ["res://assets/obs_ladder.png",     30,  90,  false],
    ["res://assets/obs_satellite.png",  55,  70,  false],
    ["res://assets/obs_vent.png",       70,  45,  false],
    ["res://assets/obs_pole.png",       40,  60,  false],
    ["res://assets/obs_billboard.png",  80,  70,  false],
    ["res://assets/obs_tall.png",       30, 120,  false],
    ["res://assets/obs_crate.png",      60,  60,  false],
    ["res://assets/obs_arch.png",      160,  50,  true],
    ["res://assets/obs_low.png",       200,  30,  true],
]

func _ready():
    # Pre-spawn 8 platforms immediately so the player always lands on solid ground
    for i in range(8):
        spawn_chunk(true)

func _process(_delta):
    if not player:
        return
    distance = player.global_position.x / 100.0
    hud_score.text = "Distance: %dm  Score: %d" % [int(distance), score]

    # Keep spawning ahead
    if player.global_position.x + 2000 > chunk_x:
        spawn_chunk(false)

    # Remove chunks that are far behind the player
    for c in chunks.duplicate():
        if c and is_instance_valid(c) and c.position.x < player.global_position.x - 1500:
            c.queue_free()
            chunks.erase(c)

func spawn_chunk(is_start: bool):
    var root = Node2D.new()
    root.position = Vector2(chunk_x, 0)
    add_child(root)
    chunks.append(root)

    # First few platforms are flat at a fixed height so player lands safely
    var ground_y = 560.0
    if not is_start:
        ground_y = randf_range(480, 620)

    # Ground platform
    var gb = StaticBody2D.new()
    gb.position = Vector2(0, ground_y)
    root.add_child(gb)

    var g_spr = Sprite2D.new()
    g_spr.texture  = ground_tex
    g_spr.position = Vector2(500, 60)
    g_spr.scale    = Vector2(2.0, 1.0)
    gb.add_child(g_spr)

    var g_col = CollisionShape2D.new()
    var g_shape = RectangleShape2D.new()
    g_shape.size = Vector2(1000, 120)
    g_col.shape  = g_shape
    g_col.position = Vector2(500, 60)
    gb.add_child(g_col)

    # No obstacles on the very first 3 start chunks
    var chunk_index = int(chunk_x / 1000)
    if not is_start and chunk_index >= 3:
        if randf() > 0.25:
            root.add_child(_make_obstacle(randf_range(350, 750), ground_y))
        if randf() > 0.6:
            root.add_child(_make_obstacle(randf_range(100, 280), ground_y))

    # Coins (even on start chunks so it feels rewarding)
    for i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(120, 900), ground_y - randf_range(60, 160))
        var c_spr = Sprite2D.new()
        c_spr.texture = coin_tex
        var c_col = CollisionShape2D.new()
        var c_shape = CircleShape2D.new()
        c_shape.radius = 16
        c_col.shape = c_shape
        coin.add_child(c_spr)
        coin.add_child(c_col)
        coin.body_entered.connect(_on_coin_hit.bind(coin))
        root.add_child(coin)

    chunk_x += 1000 + randf_range(0, 80)

func _make_obstacle(offset_x: float, ground_y: float) -> Node2D:
    var info     = obs_types[randi() % obs_types.size()]
    var tex_path = info[0]
    var obs_w    = float(info[1]) * 1.4
    var obs_h    = float(info[2]) * 1.4
    var is_low   = bool(info[3])

    var obs
    if is_low:
        obs = Area2D.new()
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        obs.body_exited.connect(_on_obstacle_clear.bind(obs))
    else:
        obs = StaticBody2D.new()
        # Invisible score zone above the obstacle
        var sa = Area2D.new()
        sa.position = Vector2(0, -obs_h - 80)
        var sc = CollisionShape2D.new()
        var ss = RectangleShape2D.new()
        ss.size = Vector2(obs_w, 160)
        sc.shape = ss
        sa.add_child(sc)
        sa.body_exited.connect(_on_obstacle_clear.bind(sa))
        obs.add_child(sa)

    obs.position = Vector2(offset_x, ground_y)

    var o_spr = Sprite2D.new()
    o_spr.texture  = load(tex_path)
    o_spr.scale    = Vector2(1.4, 1.4)
    o_spr.position = Vector2(0, -obs_h * 0.5)
    obs.add_child(o_spr)

    var o_col = CollisionShape2D.new()
    var o_shape = RectangleShape2D.new()
    o_shape.size = Vector2(obs_w, obs_h)
    o_col.shape  = o_shape
    o_col.position = Vector2(0, -obs_h * 0.5)
    obs.add_child(o_col)
    return obs

func show_popup(text_str, pos):
    var lbl = Label.new()
    lbl.text = text_str
    lbl.global_position = pos + Vector2(-20, -50)
    lbl.add_theme_color_override("font_color", Color(1, 1, 0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100, 1.0)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obstacle_hit(body, _obs):
    if body.name == "Player":
        body.stun()

func _on_obstacle_clear(body, _obs):
    if body.name == "Player" and body.state != "stun":
        score += 50
        show_popup("+50", body.global_position)

func _on_coin_hit(body, coin_node):
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        show_popup("+10", coin_node.global_position)
        coin_node.queue_free()
"""

with open(os.path.join(scripts, "LevelManager.gd"), "w", encoding="utf-8") as f:
    f.write(level_gd)
print("LevelManager.gd fixed - chunks now spawn from x=0")
