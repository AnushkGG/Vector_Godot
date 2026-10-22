import os

scripts = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector\scripts"

# Fix LevelManager - remove ternary type mismatch, fix integer division
open(os.path.join(scripts,"LevelManager.gd"),"w",encoding="utf-8").write("""extends Node2D

@onready var player    = $Player
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var sfx_coin  = $SfxCoin

const GROUND_Y = 560.0
var chunk_x    = 0.0
var score      = 0
var distance   = 0.0
var chunks     = []

var ground_tex = preload("res://assets/ground.png")
var coin_tex   = preload("res://assets/coin.png")

var obs_types = [
    ["res://assets/obs_watertank.png",  50,  80, false],
    ["res://assets/obs_crane.png",     120,  90, false],
    ["res://assets/obs_ladder.png",     30,  90, false],
    ["res://assets/obs_satellite.png",  55,  70, false],
    ["res://assets/obs_vent.png",       70,  45, false],
    ["res://assets/obs_pole.png",       40,  60, false],
    ["res://assets/obs_billboard.png",  80,  70, false],
    ["res://assets/obs_tall.png",       30, 120, false],
    ["res://assets/obs_crate.png",      60,  60, false],
    ["res://assets/obs_arch.png",      160,  50, true],
    ["res://assets/obs_low.png",       200,  30, true],
]

func _ready():
    for i in range(8):
        _spawn(i < 3)

func _process(_delta):
    if not player: return
    distance = player.global_position.x / 100.0
    hud_score.text = "Distance: %dm  Score: %d" % [int(distance), score]
    if player.global_position.x + 2000.0 > chunk_x:
        _spawn(false)
    for c in chunks.duplicate():
        if c and is_instance_valid(c) and c.position.x < player.global_position.x - 1500.0:
            c.queue_free()
            chunks.erase(c)

func _spawn(safe: bool):
    var root = Node2D.new()
    root.position = Vector2(chunk_x, 0.0)
    add_child(root)
    chunks.append(root)

    var gb = StaticBody2D.new()
    gb.position = Vector2(0.0, GROUND_Y)
    root.add_child(gb)

    var gs = Sprite2D.new()
    gs.texture   = ground_tex
    gs.position  = Vector2(500.0, 60.0)
    gs.scale     = Vector2(2.0, 1.0)
    gb.add_child(gs)

    var gc = CollisionShape2D.new()
    var gr = RectangleShape2D.new()
    gr.size      = Vector2(1000.0, 120.0)
    gc.shape     = gr
    gc.position  = Vector2(500.0, 60.0)
    gb.add_child(gc)

    if not safe:
        if randf() > 0.25:
            root.add_child(_make_obs(randf_range(350.0, 750.0)))
        if randf() > 0.60:
            root.add_child(_make_obs(randf_range(100.0, 300.0)))

    for _i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(120.0, 900.0), GROUND_Y - randf_range(60.0, 160.0))
        var cs = Sprite2D.new()
        cs.texture = coin_tex
        var cc = CollisionShape2D.new()
        var cr = CircleShape2D.new()
        cr.radius = 16.0
        cc.shape  = cr
        coin.add_child(cs)
        coin.add_child(cc)
        coin.body_entered.connect(_on_coin.bind(coin))
        root.add_child(coin)

    chunk_x += 1000.0

func _make_obs(ox: float) -> Node2D:
    var info   = obs_types[randi() % obs_types.size()]
    var tex    = info[0]
    var ow     = float(info[1]) * 1.5
    var oh     = float(info[2]) * 1.5
    var is_low = bool(info[3])

    # FIX: no ternary with different node types - use if/else
    var obs: Node2D
    if is_low:
        var a = Area2D.new()
        a.body_entered.connect(_on_obs_hit.bind(a))
        a.body_exited.connect(_on_obs_clear.bind(a))
        obs = a
    else:
        var s = StaticBody2D.new()
        var sa = Area2D.new()
        sa.position = Vector2(0.0, -oh - 60.0)
        var sc = CollisionShape2D.new()
        var ss = RectangleShape2D.new()
        ss.size   = Vector2(ow, 120.0)
        sc.shape  = ss
        sa.add_child(sc)
        sa.body_exited.connect(_on_obs_clear.bind(sa))
        s.add_child(sa)
        obs = s

    obs.position = Vector2(ox, GROUND_Y)

    var sp = Sprite2D.new()
    sp.texture  = load(tex)
    sp.scale    = Vector2(1.5, 1.5)
    sp.position = Vector2(0.0, -oh * 0.5)
    obs.add_child(sp)

    var col = CollisionShape2D.new()
    var shp = RectangleShape2D.new()
    shp.size    = Vector2(ow, oh)
    col.shape   = shp
    col.position = Vector2(0.0, -oh * 0.5)
    obs.add_child(col)

    return obs

func _popup(txt: String, pos: Vector2) -> void:
    var lbl = Label.new()
    lbl.text = txt
    lbl.global_position = pos + Vector2(-20.0, -50.0)
    lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100.0, 1.0)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obs_hit(body: Node, _o) -> void:
    if body.name == "Player":
        body.stun()

func _on_obs_clear(body: Node, _o) -> void:
    if body.name == "Player" and not body.stunned:
        score += 50
        _popup("+50", body.global_position)

func _on_coin(body: Node, coin: Node) -> void:
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        _popup("+10", coin.global_position)
        coin.queue_free()
""")

# Fix Player - integer division warning fix
open(os.path.join(scripts,"Player.gd"),"w",encoding="utf-8").write("""extends CharacterBody2D

const RUN_SPEED     = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY       = 1600.0

var state      = "run"
var stunned    = false
var stun_timer = 0.0
var trail      = []

@onready var anim       = $Sprite2D
@onready var dust       = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide  = $ColSlide
@onready var sfx_jump   = $SfxJump
@onready var sfx_hit    = $SfxHit

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        if stunned:
            stunned = false
            stun_timer = 0.0
            state = "run"
            modulate = Color(1.0, 1.0, 1.0)
        if state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()

    if stunned:
        stun_timer -= delta
        velocity.x = 0.0
        if stun_timer <= 0.0:
            stunned = false
            state   = "run"
            modulate = Color(1.0, 1.0, 1.0)
    else:
        velocity.x = RUN_SPEED
        if Input.is_action_pressed("slide") and is_on_floor():
            state = "slide"
            col_normal.disabled = true
            col_slide.disabled  = false
            dust.emitting       = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled  = true
                dust.emitting       = false
        if not is_on_floor():
            if velocity.y < 0.0:
                state = "jump"
            else:
                state = "fall"
        elif state != "slide":
            state = "run"

    # FIX: explicit int cast to avoid integer division warning
    var frame_idx: int = (int(Engine.get_frames_drawn()) / 10) % 2
    var rx: int = 0
    if state == "run" or stunned:
        rx = frame_idx * 100
    elif state == "jump" or state == "fall":
        rx = 200
    elif state == "slide":
        rx = 300
    anim.region_rect = Rect2(rx, 0, 100, 100)

    move_and_slide()

    if global_position.y > 900.0 and state != "dead":
        state = "dead"
        set_physics_process(false)
        await get_tree().create_timer(0.4).timeout
        get_tree().reload_current_scene()
        return

    trail.append({"pos": global_position, "state": state})
    if trail.size() > 360:
        trail.pop_front()

func stun() -> void:
    if stunned or state == "dead":
        return
    stunned    = true
    stun_timer = 1.2
    state      = "stun"
    sfx_hit.play()
    modulate   = Color(1.0, 0.3, 0.3)
""")

# Fix Chaser - same integer division fix
open(os.path.join(scripts,"Chaser.gd"),"w",encoding="utf-8").write("""extends Node2D

@export var player_path: NodePath
var player       = null
var anim         = null
var delay_frames = 35
var catchup      = 0.0
var game_over    = false

func _ready() -> void:
    player = get_node_or_null(player_path)
    anim   = get_node_or_null("Sprite2D")

func _physics_process(delta: float) -> void:
    if game_over or not player:
        return
    if player.trail.size() == 0:
        return

    if player.stunned:
        delay_frames = max(5, delay_frames - 2)
    else:
        if delay_frames < 35:
            catchup += delta
            if catchup > 0.08:
                delay_frames += 1
                catchup = 0.0

    var idx: int  = max(0, player.trail.size() - delay_frames - 1)
    var data      = player.trail[idx]
    global_position = data["pos"]

    if anim:
        var frame_idx: int = (int(Engine.get_frames_drawn()) / 10) % 2
        var rx: int = 0
        var s: String = data["state"]
        if s == "run" or s == "stun":
            rx = frame_idx * 100
        elif s == "jump" or s == "fall":
            rx = 200
        elif s == "slide":
            rx = 300
        anim.region_rect = Rect2(rx, 0, 100, 100)

    if global_position.distance_to(player.global_position) < 50.0:
        game_over = true
        if player.has_method("set_physics_process"):
            player.set_physics_process(false)
        await get_tree().create_timer(1.0).timeout
        get_tree().reload_current_scene()
""")

print("All 3 scripts fixed - no more type errors!")
print("In Godot: Reload All -> Play")
