import os

scripts = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector\scripts"

# ── PLAYER.GD: allow jump even when stunned, resume run immediately on jump ──
player_gd = """extends CharacterBody2D

const RUN_SPEED = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY = 1600.0

var state = "run"
var stun_timer = 0.0
var trail = []

@onready var anim       = $Sprite2D
@onready var dust       = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide  = $ColSlide
@onready var sfx_jump   = $SfxJump
@onready var sfx_hit    = $SfxHit

func _physics_process(delta):
    # Gravity always applies
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # JUMP can ALWAYS cancel stun - player can jump out of a block
    if Input.is_action_just_pressed("jump") and is_on_floor():
        if state == "stun":
            state = "run"          # cancel stun
            stun_timer = 0.0
            modulate = Color(1, 1, 1)
        if state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()

    if state == "stun":
        stun_timer -= delta
        velocity.x = 0            # fully stopped against obstacle
        if stun_timer <= 0:
            state = "run"
    else:
        velocity.x = RUN_SPEED

        # Slide input
        if Input.is_action_pressed("slide") and is_on_floor():
            state = "slide"
            col_normal.disabled = true
            col_slide.disabled  = false
            dust.emitting = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled  = true
                dust.emitting = false

        # Air state
        if not is_on_floor():
            state = "jump" if velocity.y < 0 else "fall"
        elif state not in ["slide"]:
            state = "run"

    # Animation frame (sprite sheet: 0=run1, 100=run2, 200=jump, 300=slide)
    var rect_x = 0
    if state == "run" or state == "stun":
        rect_x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        rect_x = 200
    elif state == "slide":
        rect_x = 300

    anim.region_rect = Rect2(rect_x, 0, 100, 100)
    move_and_slide()

    # Fall death
    if global_position.y > 900 and state != "dead":
        state = "dead"
        set_physics_process(false)
        await get_tree().create_timer(0.5).timeout
        get_tree().reload_current_scene()
        return

    trail.append({"pos": global_position, "state": state})
    if trail.size() > 300:
        trail.pop_front()

func stun():
    if state == "stun" or state == "dead":
        return
    state = "stun"
    stun_timer = 1.0
    sfx_hit.play()
    modulate = Color(1, 0.4, 0.4)
    await get_tree().create_timer(1.0).timeout
    if state == "stun":        # only reset if still stunned (not jumped out)
        modulate = Color(1, 1, 1)
"""

# ── LEVELMANAGER.GD: chunk is Node2D, ground+obstacles are SEPARATE children ──
level_gd = """# Vector Runner - Level Manager
extends Node2D

@onready var player     = $Player
@onready var hud_score  = $CanvasLayer/HUD/Score
@onready var sfx_coin   = $SfxCoin

var chunk_x  = 2000.0
var score    = 0
var distance = 0.0

var ground_tex = preload("res://assets/ground.png")
var coin_tex   = preload("res://assets/coin.png")

# [tex_path, width, height, is_low_beam]
# all dimensions are in pixels; we will scale up by 1.5x in code
var obs_types = [
    ["res://assets/obs_watertank.png", 50,  80,  false],
    ["res://assets/obs_crane.png",    120,  90,  false],
    ["res://assets/obs_ladder.png",    30,  90,  false],
    ["res://assets/obs_satellite.png", 55,  70,  false],
    ["res://assets/obs_vent.png",      70,  45,  false],
    ["res://assets/obs_pole.png",      40,  60,  false],
    ["res://assets/obs_billboard.png", 80,  70,  false],
    ["res://assets/obs_tall.png",      30, 120,  false],
    ["res://assets/obs_crate.png",     60,  60,  false],
    ["res://assets/obs_arch.png",     160,  50,  true],
    ["res://assets/obs_low.png",      200,  30,  true],
]

func _process(_delta):
    if not player:
        return
    distance = player.global_position.x / 100.0
    hud_score.text = "Distance: %dm  Score: %d" % [int(distance), score]
    if player.global_position.x + 1500 > chunk_x:
        spawn_chunk()

func spawn_chunk():
    # Root wrapper (plain Node2D - NOT a physics body)
    var root = Node2D.new()
    root.position = Vector2(chunk_x, 0)
    add_child(root)

    # ── Ground platform (its own StaticBody2D)
    var ground_y = randf_range(500, 640)
    var gb = StaticBody2D.new()
    gb.position = Vector2(0, ground_y)
    root.add_child(gb)

    var g_spr = Sprite2D.new()
    g_spr.texture = ground_tex
    g_spr.position = Vector2(500, 60)
    g_spr.scale    = Vector2(2.0, 1.0)
    gb.add_child(g_spr)

    var g_col = CollisionShape2D.new()
    var g_shape = RectangleShape2D.new()
    g_shape.size = Vector2(1000, 120)
    g_col.shape  = g_shape
    g_col.position = Vector2(500, 60)
    gb.add_child(g_col)

    # ── Obstacles (added to root, NOT to the ground StaticBody2D)
    if randf() > 0.2:
        var obs = _make_obstacle(randf_range(300, 750), ground_y)
        root.add_child(obs)

    if randf() > 0.6:
        var obs2 = _make_obstacle(randf_range(80, 260), ground_y)
        root.add_child(obs2)

    # ── Coins
    for i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(100, 900), ground_y - randf_range(60, 160))
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

    chunk_x += 1000 + randf_range(50, 150)

func _make_obstacle(offset_x: float, ground_y: float) -> Node2D:
    var info     = obs_types[randi() % obs_types.size()]
    var tex_path = info[0]
    var obs_w    = float(info[1]) * 1.4
    var obs_h    = float(info[2]) * 1.4
    var is_low   = bool(info[3])

    # Solid obstacle -> StaticBody2D so player physically stops and can climb it
    # Low beam      -> Area2D (pass-through stun zone, player must slide)
    var obs
    if is_low:
        obs = Area2D.new()
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        obs.body_exited.connect(_on_obstacle_clear.bind(obs))
    else:
        obs = StaticBody2D.new()
        # Invisible score trigger just above the obstacle top
        var sa = Area2D.new()
        sa.position = Vector2(0, -obs_h - 80)
        var sc = CollisionShape2D.new()
        var ss = RectangleShape2D.new()
        ss.size = Vector2(obs_w, 160)
        sc.shape = ss
        sa.add_child(sc)
        sa.body_exited.connect(_on_obstacle_clear.bind(sa))
        obs.add_child(sa)

    # Position: sit on top of the ground surface
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

with open(os.path.join(scripts, "Player.gd"), "w", encoding="utf-8") as f:
    f.write(player_gd)
print("Player.gd fixed")

with open(os.path.join(scripts, "LevelManager.gd"), "w", encoding="utf-8") as f:
    f.write(level_gd)
print("LevelManager.gd fixed")
print("Done! Reload in Godot and press Play.")
