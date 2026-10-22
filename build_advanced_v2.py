import os
import math
import struct
import wave
import shutil
import glob
from PIL import Image, ImageDraw

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets_dir = os.path.join(base_dir, "assets")
scenes_dir = os.path.join(base_dir, "scenes")
scripts_dir = os.path.join(base_dir, "scripts")

os.makedirs(assets_dir, exist_ok=True)
os.makedirs(scenes_dir, exist_ok=True)
os.makedirs(scripts_dir, exist_ok=True)

# Find vector_bg.png in the brain artifact folder and copy it
brain_dir = r"C:\Users\ANANYA KOMARWAR\.gemini\antigravity\brain\2c8d3740-7d53-4136-876d-9ed573714151"
bg_files = glob.glob(os.path.join(brain_dir, "vector_bg_*.png"))
if bg_files:
    shutil.copy(bg_files[-1], os.path.join(assets_dir, "vector_bg.png"))
else:
    # Fallback to gradient
    img = Image.new('RGB', (1280, 720))
    ImageDraw.Draw(img).rectangle([0,0,1280,720], fill=(255, 100, 50))
    img.save(os.path.join(assets_dir, "vector_bg.png"))

# Parallax city layers
def draw_city(path, size, base_color, building_width, add_windows=False):
    img = Image.new('RGBA', size, (0,0,0,0))
    draw = ImageDraw.Draw(img)
    x = 0
    import random
    random.seed(42)
    while x < size[0]:
        w = random.randint(building_width//2, building_width)
        h = random.randint(size[1]//3, int(size[1]*0.8))
        draw.rectangle([x, size[1]-h, x+w, size[1]], fill=base_color)
        if add_windows:
            for wx in range(x+10, x+w-10, 20):
                for wy in range(size[1]-h+20, size[1]-20, 30):
                    if random.random() > 0.6:
                        draw.rectangle([wx, wy, wx+10, wy+15], fill=(255, 200, 100, 255))
        x += w
    img.save(path)

draw_city(os.path.join(assets_dir, "city_far.png"), (1280, 720), (80, 80, 100, 255), 150)
draw_city(os.path.join(assets_dir, "city_mid.png"), (1280, 720), (50, 50, 70, 255), 200, True)

# Platform / Ground
g_img = Image.new('RGBA', (500, 200), (0,0,0,0))
gd = ImageDraw.Draw(g_img)
gd.rectangle([0, 0, 500, 200], fill=(20, 20, 20, 255))
gd.line([0, 0, 500, 0], fill=(100, 100, 100, 255), width=3)
g_img.save(os.path.join(assets_dir, "ground.png"))

# Obstacles
obs_tall = Image.new('RGBA', (30, 120), (40,40,40,255))
ImageDraw.Draw(obs_tall).rectangle([5, 0, 25, 120], fill=(100,20,20,255))
obs_tall.save(os.path.join(assets_dir, "obs_tall.png"))

obs_low = Image.new('RGBA', (200, 80), (0,0,0,0))
ImageDraw.Draw(obs_low).rectangle([0, 0, 20, 80], fill=(60,60,60,255))
ImageDraw.Draw(obs_low).rectangle([180, 0, 200, 80], fill=(60,60,60,255))
ImageDraw.Draw(obs_low).rectangle([0, 0, 200, 20], fill=(80,80,80,255))
obs_low.save(os.path.join(assets_dir, "obs_low.png"))

obs_crate = Image.new('RGBA', (60, 60), (139,69,19,255))
ImageDraw.Draw(obs_crate).rectangle([5,5,55,55], outline=(100,50,10,255), width=4)
ImageDraw.Draw(obs_crate).line([5,5,55,55], fill=(100,50,10,255), width=4)
obs_crate.save(os.path.join(assets_dir, "obs_crate.png"))

# Collectibles
c_img = Image.new('RGBA', (32, 32), (0,0,0,0))
ImageDraw.Draw(c_img).ellipse([4,4,28,28], fill=(255,215,0,255), outline=(255,255,255,255), width=2)
c_img.save(os.path.join(assets_dir, "coin.png"))

# Stickman Generator
def draw_stickman(action, color):
    img = Image.new('RGBA', (100, 100), (0,0,0,0))
    d = ImageDraw.Draw(img)
    if action == "slide":
        d.ellipse([60, 60, 80, 80], fill=color)
        d.line([40, 70, 70, 70], fill=color, width=6)
        d.line([40, 70, 10, 80], fill=color, width=4)
        d.line([70, 70, 90, 80], fill=color, width=4)
    else:
        d.ellipse([40, 10, 60, 30], fill=color)
        d.line([50, 30, 50, 60], fill=color, width=6)
        if action == "run_1":
            d.line([50, 60, 30, 90], fill=color, width=5)
            d.line([50, 60, 70, 90], fill=color, width=5)
            d.line([50, 40, 20, 50], fill=color, width=4)
            d.line([50, 40, 80, 50], fill=color, width=4)
        elif action == "run_2":
            d.line([50, 60, 40, 80], fill=color, width=5)
            d.line([50, 60, 60, 80], fill=color, width=5)
            d.line([50, 40, 30, 60], fill=color, width=4)
            d.line([50, 40, 70, 60], fill=color, width=4)
        elif action == "jump":
            d.line([50, 60, 30, 70], fill=color, width=5) 
            d.line([50, 60, 60, 80], fill=color, width=5) 
            d.line([50, 40, 30, 20], fill=color, width=4) 
            d.line([50, 40, 70, 20], fill=color, width=4) 
    return img

def create_sprite_sheet(path, color):
    frames = [
        draw_stickman("run_1", color),
        draw_stickman("run_2", color),
        draw_stickman("jump", color),
        draw_stickman("slide", color)
    ]
    sheet = Image.new('RGBA', (400, 100), (0,0,0,0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i*100, 0))
    sheet.save(path)

create_sprite_sheet(os.path.join(assets_dir, "player_sheet.png"), "black")
create_sprite_sheet(os.path.join(assets_dir, "chaser_sheet.png"), (50, 0, 0, 255))

p_img = Image.new('RGBA', (8, 8), (0,0,0,0))
ImageDraw.Draw(p_img).ellipse([0,0,8,8], fill=(255,255,255,200))
p_img.save(os.path.join(assets_dir, "particle.png"))

btn = Image.new('RGBA', (200, 200), (255,255,255,50))
ImageDraw.Draw(btn).ellipse([10,10,190,190], outline=(255,255,255,100), width=10)
btn.save(os.path.join(assets_dir, "ui_btn.png"))

def generate_wav(path, freq_start, freq_end, duration, sample_rate=44100):
    num_samples = int(duration * sample_rate)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        for i in range(num_samples):
            t = float(i) / sample_rate
            freq = freq_start + (freq_end - freq_start) * (i / num_samples)
            value = int(32767.0 * 0.5 * math.sin(2.0 * math.pi * freq * t))
            w.writeframes(struct.pack('h', value))

generate_wav(os.path.join(assets_dir, "jump.wav"), 200, 600, 0.2)
generate_wav(os.path.join(assets_dir, "coin.wav"), 800, 1200, 0.1)
generate_wav(os.path.join(assets_dir, "hit.wav"), 100, 50, 0.3)

# ---------------------------------------------------------
# SCRIPTS (Fixing flicker and syntax)
# ---------------------------------------------------------
scripts = {
    "Player.gd": """extends CharacterBody2D

const RUN_SPEED = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY = 1600.0

var state = "run"
var stun_timer = 0.0
var trail = []

@onready var anim = $Sprite2D
@onready var dust = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide = $ColSlide
@onready var sfx_jump = $SfxJump
@onready var sfx_hit = $SfxHit

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    if state == "stun":
        stun_timer -= delta
        velocity.x = RUN_SPEED * 0.4
        if stun_timer <= 0:
            state = "run"
    else:
        velocity.x = RUN_SPEED
        if Input.is_action_pressed("slide") and is_on_floor():
            state = "slide"
            col_normal.disabled = true
            col_slide.disabled = false
            dust.emitting = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled = true
                dust.emitting = false
                
        if Input.is_action_just_pressed("jump") and is_on_floor() and state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()
            
        if not is_on_floor():
            if velocity.y < 0:
                state = "jump"
            else:
                state = "fall"
        elif state != "slide":
            state = "run"

    var rect_x = 0
    if state == "run":
        rect_x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        rect_x = 200
    elif state == "slide":
        rect_x = 300
        
    anim.region_rect = Rect2(rect_x, 0, 100, 100)
    move_and_slide()
    
    trail.append({"pos": global_position, "state": state})
    if trail.size() > 300: 
        trail.pop_front()

func stun():
    if state != "stun":
        state = "stun"
        stun_timer = 1.0
        sfx_hit.play()
        modulate = Color(1, 0.5, 0.5)
        await get_tree().create_timer(1.0).timeout
        modulate = Color(1, 1, 1)
""",
    
    "Chaser.gd": """extends Node2D

@export var player_path: NodePath
@onready var player = get_node(player_path)
@onready var anim = $Sprite2D

var delay_frames = 60
var current_catch_up = 0.0

func _physics_process(delta):
    if not player or player.trail.size() == 0:
        return
        
    if player.state == "stun":
        delay_frames = max(10, delay_frames - 1)
    else:
        if delay_frames < 60:
            current_catch_up += delta
            if current_catch_up > 0.1:
                delay_frames += 1
                current_catch_up = 0
                
    var target_idx = player.trail.size() - delay_frames - 1
    if target_idx < 0:
        target_idx = 0
        
    var data = player.trail[target_idx]
    global_position = data["pos"]
    var p_state = data["state"]
    
    var rect_x = 0
    if p_state == "run" or p_state == "stun":
        rect_x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif p_state == "jump" or p_state == "fall":
        rect_x = 200
    elif p_state == "slide":
        rect_x = 300
        
    anim.region_rect = Rect2(rect_x, 0, 100, 100)
        
    if global_position.distance_to(player.global_position) < 40:
        get_tree().reload_current_scene()
""",

    "LevelManager.gd": """extends Node2D

@onready var player = $Player
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var sfx_coin = $SfxCoin
var chunk_x = 2000.0
var score = 0
var distance = 0.0

var ground_tex = preload("res://assets/ground.png")
var obs_tall_tex = preload("res://assets/obs_tall.png")
var obs_low_tex = preload("res://assets/obs_low.png")
var obs_crate_tex = preload("res://assets/obs_crate.png")
var coin_tex = preload("res://assets/coin.png")

func _process(_delta):
    if player:
        distance = player.global_position.x / 100.0
        hud_score.text = "Distance: %dm | Score: %d" % [int(distance), score]
        
        # Spawn chunks far ahead of the player
        if player.global_position.x + 1500 > chunk_x:
            spawn_chunk()

func spawn_chunk():
    var chunk = StaticBody2D.new()
    chunk.position = Vector2(chunk_x, randf_range(500, 650))
    add_child(chunk)
    
    var spr = Sprite2D.new()
    spr.texture = ground_tex
    spr.position = Vector2(500, 100)
    spr.scale = Vector2(2.0, 1.0)
    chunk.add_child(spr)
    
    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(1000, 200)
    col.shape = shape
    col.position = Vector2(500, 100)
    chunk.add_child(col)
    
    if randf() > 0.5:
        var type = randi() % 3
        var obs = Area2D.new()
        obs.position = Vector2(randf_range(200, 800), 0)
        var o_spr = Sprite2D.new()
        var o_col = CollisionShape2D.new()
        var o_shape = RectangleShape2D.new()
        if type == 0:
            o_spr.texture = obs_tall_tex
            o_spr.position = Vector2(0, -60)
            o_shape.size = Vector2(30, 120)
        elif type == 1:
            o_spr.texture = obs_low_tex
            o_spr.position = Vector2(0, -40)
            o_shape.size = Vector2(200, 80)
        else:
            o_spr.texture = obs_crate_tex
            o_spr.position = Vector2(0, -30)
            o_shape.size = Vector2(60, 60)
        o_col.shape = o_shape
        o_col.position = o_spr.position
        obs.add_child(o_spr)
        obs.add_child(o_col)
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        obs.body_exited.connect(_on_obstacle_clear.bind(obs))
        chunk.add_child(obs)
        
    for i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(100, 900), -randf_range(50, 150))
        var c_spr = Sprite2D.new()
        c_spr.texture = coin_tex
        var c_col = CollisionShape2D.new()
        var c_shape = CircleShape2D.new()
        c_shape.radius = 16
        c_col.shape = c_shape
        coin.add_child(c_spr)
        coin.add_child(c_col)
        coin.body_entered.connect(_on_coin_hit.bind(coin))
        chunk.add_child(coin)
        
    chunk_x += 1000 + randf_range(150, 300)

func show_popup(text_str, pos):
    var lbl = Label.new()
    lbl.text = text_str
    lbl.global_position = pos + Vector2(-20, -50)
    lbl.add_theme_color_override("font_color", Color(1,1,0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100, 1.0)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obstacle_hit(body, obs_node):
    if body.name == "Player":
        body.stun()

func _on_obstacle_clear(body, obs_node):
    if body.name == "Player" and body.state != "stun":
        score += 50
        show_popup("Swallow\\n+50", body.global_position)

func _on_coin_hit(body, coin_node):
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        show_popup("+10", coin_node.global_position)
        coin_node.queue_free()
"""
}
for name, content in scripts.items():
    with open(os.path.join(scripts_dir, name), "w") as f:
        f.write(content)

# ---------------------------------------------------------
# SCENES (Camera2D attached to Player)
# ---------------------------------------------------------
scenes = {
    "Main.tscn": """[gd_scene load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/LevelManager.gd" id="1_lvl"]
[ext_resource type="Texture2D" path="res://assets/vector_bg.png" id="2_sky"]
[ext_resource type="Texture2D" path="res://assets/city_far.png" id="3_far"]
[ext_resource type="Texture2D" path="res://assets/city_mid.png" id="4_mid"]
[ext_resource type="Texture2D" path="res://assets/ground.png" id="5_gnd"]
[ext_resource type="PackedScene" path="res://scenes/Player.tscn" id="6_plr"]
[ext_resource type="PackedScene" path="res://scenes/Chaser.tscn" id="7_chs"]
[ext_resource type="AudioStream" path="res://assets/coin.wav" id="8_sfx"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_gnd"]
size = Vector2(2500, 200)

[node name="Main" type="Node2D"]
script = ExtResource("1_lvl")

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]
[node name="SkyLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/SkyLayer"]
texture = ExtResource("2_sky")
centered = false

[node name="CityFarLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.1, 0)
motion_mirroring = Vector2(1280, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/CityFarLayer"]
texture = ExtResource("3_far")
centered = false

[node name="CityMidLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.3, 0)
motion_mirroring = Vector2(1280, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/CityMidLayer"]
texture = ExtResource("4_mid")
centered = false

[node name="StartGround" type="StaticBody2D" parent="."]
position = Vector2(0, 600)
[node name="Sprite2D" type="Sprite2D" parent="StartGround"]
position = Vector2(1250, 100)
scale = Vector2(5, 1)
texture = ExtResource("5_gnd")
[node name="CollisionShape2D" type="CollisionShape2D" parent="StartGround"]
position = Vector2(1250, 100)
shape = SubResource("RectangleShape2D_gnd")

[node name="Player" parent="." instance=ExtResource("6_plr")]
position = Vector2(400, 500)

[node name="Camera2D" type="Camera2D" parent="Player"]
position = Vector2(200, -100)
limit_bottom = 1000
position_smoothing_enabled = true

[node name="Chaser" parent="." instance=ExtResource("7_chs")]
position = Vector2(50, 500)
player_path = NodePath("../Player")

[node name="SfxCoin" type="AudioStreamPlayer" parent="."]
stream = ExtResource("8_sfx")

[node name="CanvasLayer" type="CanvasLayer" parent="."]
[node name="HUD" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
[node name="Score" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 20.0
offset_top = 20.0
offset_right = 400.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_font_sizes/font_size = 32
text = "Distance: 0m | Score: 0"
""",
    
    "Player.tscn": """[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://scripts/Player.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/player_sheet.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/particle.png" id="3_prt"]
[ext_resource type="AudioStream" path="res://assets/jump.wav" id="4_sfx"]
[ext_resource type="AudioStream" path="res://assets/hit.wav" id="5_sfx"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_norm"]
size = Vector2(30, 80)
[sub_resource type="RectangleShape2D" id="RectangleShape2D_slide"]
size = Vector2(80, 40)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)

[node name="ColNormal" type="CollisionShape2D" parent="."]
position = Vector2(0, 10)
shape = SubResource("RectangleShape2D_norm")

[node name="ColSlide" type="CollisionShape2D" parent="."]
position = Vector2(0, 30)
shape = SubResource("RectangleShape2D_slide")
disabled = true

[node name="DustParticles" type="CPUParticles2D" parent="."]
position = Vector2(-20, 40)
emitting = false
amount = 16
texture = ExtResource("3_prt")
gravity = Vector2(-200, -100)
initial_velocity_min = 50.0
initial_velocity_max = 100.0
scale_amount_min = 0.5
scale_amount_max = 2.0
color = Color(0.8, 0.8, 0.8, 0.5)

[node name="SfxJump" type="AudioStreamPlayer" parent="."]
stream = ExtResource("4_sfx")
[node name="SfxHit" type="AudioStreamPlayer" parent="."]
stream = ExtResource("5_sfx")
""",

    "Chaser.tscn": """[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2_tex"]

[node name="Chaser" type="Node2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)
"""
}

for name, content in scenes.items():
    with open(os.path.join(scenes_dir, name), "w") as f:
        f.write(content)
        
project_godot = """
; Engine configuration file.
[application]
config/name="Vector Godot Runner Advanced V2"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
slide={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
"""
with open(os.path.join(base_dir, "project.godot"), "w") as f:
    f.write(project_godot.strip())

print("V2 build generated perfectly.")
