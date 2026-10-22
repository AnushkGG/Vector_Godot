import os, shutil, math, struct, wave
from PIL import Image, ImageDraw

base    = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets  = os.path.join(base, "assets")
scripts = os.path.join(base, "scripts")
scenes  = os.path.join(base, "scenes")

# Clear Godot cache to force fresh import
godot_cache = os.path.join(base, ".godot")
if os.path.exists(godot_cache):
    shutil.rmtree(godot_cache)
    print("Cleared .godot cache")

os.makedirs(assets, exist_ok=True)
os.makedirs(scripts, exist_ok=True)
os.makedirs(scenes, exist_ok=True)

# ═══════════════════════════════════════════════════════════
# SPRITES - muscular man (BLACK player, DARK RED chaser)
# ═══════════════════════════════════════════════════════════
def draw_man(pose, color):
    img = Image.new('RGBA', (100, 100), (0,0,0,0))
    d = ImageDraw.Draw(img)
    def limb(ax,ay,bx,by,w):
        d.line([(ax,ay),(bx,by)], fill=color, width=w)
        r=w//2
        d.ellipse([ax-r,ay-r,ax+r,ay+r], fill=color)
        d.ellipse([bx-r,by-r,bx+r,by+r], fill=color)
    if pose == 'run1':
        d.ellipse([43,5,59,21], fill=color)
        d.polygon([(51,20),(63,27),(56,55),(42,51),(43,25)], fill=color)
        limb(54,31, 39,45, 9); limb(39,45, 29,37, 7)
        limb(56,31, 71,43, 9); limb(71,43, 79,35, 7)
        limb(49,52, 35,73,11); limb(35,73, 45,95, 9)
        limb(54,52, 67,69,11); limb(67,69, 55,87, 9)
    elif pose == 'run2':
        d.ellipse([43,5,59,21], fill=color)
        d.polygon([(51,20),(63,27),(56,55),(42,51),(43,25)], fill=color)
        limb(54,31, 70,43, 9); limb(70,43, 78,54, 7)
        limb(56,31, 39,45, 9); limb(39,45, 31,37, 7)
        limb(54,52, 65,75,11); limb(65,75, 51,95, 9)
        limb(49,52, 37,71,11); limb(37,71, 47,89, 9)
    elif pose == 'jump':
        d.ellipse([39,2,55,18], fill=color)
        d.polygon([(47,17),(59,22),(54,49),(40,47),(39,22)], fill=color)
        limb(51,27, 69,15, 9); limb(69,15, 81,19, 7)
        limb(49,27, 29,17, 9); limb(29,17, 17,21, 7)
        limb(52,47, 71,35,11); limb(71,35, 61,55, 9)
        limb(46,47, 27,37,11); limb(27,37, 37,57, 9)
    elif pose == 'slide':
        d.ellipse([61,65,77,81], fill=color)
        d.polygon([(65,75),(73,83),(35,89),(31,79),(51,65)], fill=color)
        limb(35,83, 11,91,11); limb(11,91, 3,84, 9)
        limb(39,85, 21,77,11); limb(21,77, 7,81, 9)
        limb(59,75, 47,95, 9); limb(59,75, 75,93, 9)
    return img

def make_sheet(path, color):
    sheet = Image.new('RGBA', (400, 100), (0,0,0,0))
    for i, pose in enumerate(['run1','run2','jump','slide']):
        sheet.paste(draw_man(pose, color), (i*100, 0))
    sheet.save(path)

make_sheet(os.path.join(assets, "player_sheet.png"), (8,8,8,255))
make_sheet(os.path.join(assets, "chaser_sheet.png"), (155,15,15,255))
print("Sprites: player=BLACK  chaser=DARK RED")

# ═══════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════
def gen_wav(path, f0, f1, dur, vol=0.5, sr=44100):
    n = int(dur*sr)
    with wave.open(path,'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        for i in range(n):
            t=i/sr; f=f0+(f1-f0)*(i/n); env=1-(i/n)
            w.writeframes(struct.pack('h',int(32767*vol*env*math.sin(2*math.pi*f*t))))

for p,a,b,d in [("jump.wav",250,700,.22),("coin.wav",900,1400,.10),("hit.wav",150,60,.30)]:
    gen_wav(os.path.join(assets,p),a,b,d)
print("Audio generated")

# ═══════════════════════════════════════════════════════════
# SCRIPTS
# ═══════════════════════════════════════════════════════════

# ── Player.gd ──────────────────────────────────────────────
open(os.path.join(scripts,"Player.gd"),"w",encoding="utf-8").write("""extends CharacterBody2D

const RUN_SPEED     = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY       = 1600.0
const GROUND_Y      = 560.0

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

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # Jump always works - also breaks out of stun
    if Input.is_action_just_pressed("jump") and is_on_floor():
        if stunned:
            stunned = false; stun_timer = 0.0
            state = "run"; modulate = Color(1,1,1)
        if state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()

    if stunned:
        stun_timer -= delta
        velocity.x = 0.0
        if stun_timer <= 0.0:
            stunned = false; state = "run"
            modulate = Color(1,1,1)
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
            state = "jump" if velocity.y < 0.0 else "fall"
        elif state != "slide":
            state = "run"

    var rx = 0
    if state == "run" or stunned:
        rx = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        rx = 200
    elif state == "slide":
        rx = 300
    anim.region_rect = Rect2(rx, 0, 100, 100)

    move_and_slide()

    if global_position.y > 900 and state != "dead":
        state = "dead"
        set_physics_process(false)
        await get_tree().create_timer(0.4).timeout
        get_tree().reload_current_scene()
        return

    trail.append({"pos": global_position, "state": state})
    if trail.size() > 360:
        trail.pop_front()

func stun():
    if stunned or state == "dead":
        return
    stunned    = true
    stun_timer = 1.2
    state      = "stun"
    sfx_hit.play()
    modulate   = Color(1.0, 0.3, 0.3)
""")

# ── Chaser.gd ──────────────────────────────────────────────
open(os.path.join(scripts,"Chaser.gd"),"w",encoding="utf-8").write("""extends Node2D

@export var player_path: NodePath
var player       = null
var anim         = null
var delay_frames = 35
var catchup      = 0.0
var game_over    = false

func _ready():
    player = get_node_or_null(player_path)
    anim   = get_node_or_null("Sprite2D")

func _physics_process(delta):
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
                delay_frames += 1; catchup = 0.0

    var idx  = max(0, player.trail.size() - delay_frames - 1)
    var data = player.trail[idx]
    global_position = data["pos"]

    if anim:
        var rx = 0
        match data["state"]:
            "run","stun": rx = (Engine.get_frames_drawn() / 10 % 2) * 100
            "jump","fall": rx = 200
            "slide":       rx = 300
        anim.region_rect = Rect2(rx, 0, 100, 100)

    if global_position.distance_to(player.global_position) < 50:
        game_over = true
        if player.has_method("set_physics_process"):
            player.set_physics_process(false)
        await get_tree().create_timer(1.0).timeout
        get_tree().reload_current_scene()
""")

# ── LevelManager.gd ────────────────────────────────────────
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
    if player.global_position.x + 2000 > chunk_x:
        _spawn(false)
    for c in chunks.duplicate():
        if c and is_instance_valid(c) and c.position.x < player.global_position.x - 1500:
            c.queue_free(); chunks.erase(c)

func _spawn(safe: bool):
    var root = Node2D.new()
    root.position = Vector2(chunk_x, 0)
    add_child(root); chunks.append(root)

    var gb = StaticBody2D.new()
    gb.position = Vector2(0, GROUND_Y)
    root.add_child(gb)
    var gs = Sprite2D.new(); gs.texture = ground_tex
    gs.position = Vector2(500,60); gs.scale = Vector2(2,1); gb.add_child(gs)
    var gc = CollisionShape2D.new()
    var gr = RectangleShape2D.new(); gr.size = Vector2(1000,120)
    gc.shape = gr; gc.position = Vector2(500,60); gb.add_child(gc)

    if not safe:
        if randf() > 0.25: root.add_child(_make_obs(randf_range(350,750)))
        if randf() > 0.60: root.add_child(_make_obs(randf_range(100,300)))

    for _i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(120,900), GROUND_Y - randf_range(60,160))
        var cs = Sprite2D.new(); cs.texture = coin_tex
        var cc = CollisionShape2D.new()
        var cr = CircleShape2D.new(); cr.radius = 16; cc.shape = cr
        coin.add_child(cs); coin.add_child(cc)
        coin.body_entered.connect(_on_coin.bind(coin))
        root.add_child(coin)

    chunk_x += 1000.0

func _make_obs(ox: float) -> Node2D:
    var info   = obs_types[randi() % obs_types.size()]
    var tex    = info[0]
    var ow     = float(info[1]) * 1.5
    var oh     = float(info[2]) * 1.5
    var is_low = bool(info[3])

    var obs = Area2D.new() if is_low else StaticBody2D.new()
    obs.position = Vector2(ox, GROUND_Y)

    var sp = Sprite2D.new(); sp.texture = load(tex)
    sp.scale = Vector2(1.5, 1.5); sp.position = Vector2(0, -oh*0.5)
    obs.add_child(sp)

    var col = CollisionShape2D.new()
    var shp = RectangleShape2D.new(); shp.size = Vector2(ow, oh)
    col.shape = shp; col.position = Vector2(0, -oh*0.5)
    obs.add_child(col)

    if is_low:
        obs.body_entered.connect(_on_obs_hit.bind(obs))
        obs.body_exited.connect(_on_obs_clear.bind(obs))
    else:
        # score trigger floating above solid obstacle
        var sa = Area2D.new(); sa.position = Vector2(0, -oh - 60)
        var sc = CollisionShape2D.new()
        var ss = RectangleShape2D.new(); ss.size = Vector2(ow, 120)
        sc.shape = ss; sa.add_child(sc)
        sa.body_exited.connect(_on_obs_clear.bind(sa))
        obs.add_child(sa)
    return obs

func _popup(txt, pos):
    var lbl = Label.new(); lbl.text = txt
    lbl.global_position = pos + Vector2(-20,-50)
    lbl.add_theme_color_override("font_color", Color(1,1,0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl,"global_position:y", lbl.global_position.y-100, 1.0)
    tw.parallel().tween_property(lbl,"modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obs_hit(body, _o):
    if body.name == "Player": body.stun()
func _on_obs_clear(body, _o):
    if body.name == "Player" and not body.stunned:
        score += 50; _popup("+50", body.global_position)
func _on_coin(body, coin):
    if body.name == "Player":
        score += 10; sfx_coin.play()
        _popup("+10", coin.global_position); coin.queue_free()
""")

print("Scripts written")

# ═══════════════════════════════════════════════════════════
# SCENES
# ═══════════════════════════════════════════════════════════

# Player.tscn - Camera2D INSIDE player (zero flicker, always in sync)
open(os.path.join(scenes,"Player.tscn"),"w",encoding="utf-8").write("""[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://scripts/Player.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/player_sheet.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/particle.png" id="3"]
[ext_resource type="AudioStream" path="res://assets/jump.wav" id="4"]
[ext_resource type="AudioStream" path="res://assets/hit.wav" id="5"]

[sub_resource type="RectangleShape2D" id="norm"]
size = Vector2(30, 80)
[sub_resource type="RectangleShape2D" id="slide"]
size = Vector2(80, 40)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)

[node name="ColNormal" type="CollisionShape2D" parent="."]
position = Vector2(0, 10)
shape = SubResource("norm")

[node name="ColSlide" type="CollisionShape2D" parent="."]
position = Vector2(0, 30)
shape = SubResource("slide")
disabled = true

[node name="DustParticles" type="CPUParticles2D" parent="."]
position = Vector2(-20, 40)
emitting = false
amount = 16
texture = ExtResource("3")
gravity = Vector2(-200, -100)
initial_velocity_min = 50.0
initial_velocity_max = 100.0
scale_amount_min = 0.5
scale_amount_max = 2.0
color = Color(0.8, 0.8, 0.8, 0.5)

[node name="SfxJump" type="AudioStreamPlayer" parent="."]
stream = ExtResource("4")
[node name="SfxHit" type="AudioStreamPlayer" parent="."]
stream = ExtResource("5")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(260, -200)
position_smoothing_enabled = false
limit_bottom = 900
limit_right = 99999999
zoom = Vector2(0.9, 0.9)
""")

# Chaser.tscn
open(os.path.join(scenes,"Chaser.tscn"),"w",encoding="utf-8").write("""[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2"]

[node name="Chaser" type="Node2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)
""")

# Main.tscn - NO standalone camera node
open(os.path.join(scenes,"Main.tscn"),"w",encoding="utf-8").write("""[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://scripts/LevelManager.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/city_far.png" id="3"]
[ext_resource type="Texture2D" path="res://assets/city_mid.png" id="4"]
[ext_resource type="PackedScene" path="res://scenes/Player.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/Chaser.tscn" id="6"]
[ext_resource type="AudioStream" path="res://assets/coin.wav" id="7"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]

[node name="SkyLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0, 0)
[node name="Sky" type="Sprite2D" parent="ParallaxBackground/SkyLayer"]
scale = Vector2(2, 1)
texture = ExtResource("2")
centered = false

[node name="CityFarLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.08, 0)
motion_mirroring = Vector2(2560, 0)
[node name="CityFar" type="Sprite2D" parent="ParallaxBackground/CityFarLayer"]
texture = ExtResource("3")
centered = false

[node name="CityMidLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.22, 0)
motion_mirroring = Vector2(2560, 0)
[node name="CityMid" type="Sprite2D" parent="ParallaxBackground/CityMidLayer"]
texture = ExtResource("4")
centered = false

[node name="Player" parent="." instance=ExtResource("5")]
position = Vector2(300, 520)

[node name="Chaser" parent="." instance=ExtResource("6")]
position = Vector2(60, 520)
player_path = NodePath("../Player")

[node name="SfxCoin" type="AudioStreamPlayer" parent="."]
stream = ExtResource("7")

[node name="CanvasLayer" type="CanvasLayer" parent="."]
[node name="HUD" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Score" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 16.0
offset_top = 14.0
offset_right = 700.0
offset_bottom = 52.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 28
text = "Distance: 0m  Score: 0"
""")

print("Scenes written")
print("\nDONE — Godot: Reload All -> Main.tscn -> Play")
