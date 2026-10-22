import os
import math
import struct
import wave
from PIL import Image, ImageDraw

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets_dir = os.path.join(base_dir, "assets")
scenes_dir = os.path.join(base_dir, "scenes")
scripts_dir = os.path.join(base_dir, "scripts")

os.makedirs(assets_dir, exist_ok=True)
os.makedirs(scenes_dir, exist_ok=True)
os.makedirs(scripts_dir, exist_ok=True)

# ---------------------------------------------------------
# 1. GENERATE ADVANCED ASSETS
# ---------------------------------------------------------
def create_gradient(path, size, color_top, color_bottom):
    img = Image.new('RGB', size)
    draw = ImageDraw.Draw(img)
    for y in range(size[1]):
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * (y / size[1]))
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * (y / size[1]))
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * (y / size[1]))
        draw.line([(0, y), (size[0], y)], fill=(r, g, b))
    img.save(path)

# Beautiful sunset sky
create_gradient(os.path.join(assets_dir, "sky.png"), (1280, 720), (255, 100, 50), (50, 20, 80))

# Parallax city layers
def draw_city(path, size, base_color, building_width, add_windows=False):
    img = Image.new('RGBA', size, (0,0,0,0))
    draw = ImageDraw.Draw(img)
    x = 0
    import random
    random.seed(42) # Consistent look
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
gd.line([0, 0, 500, 0], fill=(100, 100, 100, 255), width=3) # Highlight edge
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

d_img = Image.new('RGBA', (32, 32), (0,0,0,0))
ImageDraw.Draw(d_img).polygon([(16,2), (30,16), (16,30), (2,16)], fill=(0,255,255,255))
d_img.save(os.path.join(assets_dir, "diamond.png"))

# Stickman Generator (Simple Sprite Sheet)
def draw_stickman(action, color):
    # Returns an image frame
    img = Image.new('RGBA', (100, 100), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # Head
    if action == "slide":
        d.ellipse([60, 60, 80, 80], fill=color) # Head low
        d.line([40, 70, 70, 70], fill=color, width=6) # Body horizontal
        d.line([40, 70, 10, 80], fill=color, width=4) # Legs back
        d.line([70, 70, 90, 80], fill=color, width=4) # Arms forward
    else:
        d.ellipse([40, 10, 60, 30], fill=color) # Head normal
        d.line([50, 30, 50, 60], fill=color, width=6) # Body vertical
        if action == "run_1":
            d.line([50, 60, 30, 90], fill=color, width=5) # L Leg
            d.line([50, 60, 70, 90], fill=color, width=5) # R Leg
            d.line([50, 40, 20, 50], fill=color, width=4) # L Arm
            d.line([50, 40, 80, 50], fill=color, width=4) # R Arm
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
create_sprite_sheet(os.path.join(assets_dir, "chaser_sheet.png"), (50, 0, 0, 255)) # Dark red chaser

# Particles (circle)
p_img = Image.new('RGBA', (8, 8), (0,0,0,0))
ImageDraw.Draw(p_img).ellipse([0,0,8,8], fill=(255,255,255,200))
p_img.save(os.path.join(assets_dir, "particle.png"))

# Mobile UI Buttons
btn = Image.new('RGBA', (200, 200), (255,255,255,50))
ImageDraw.Draw(btn).ellipse([10,10,190,190], outline=(255,255,255,100), width=10)
btn.save(os.path.join(assets_dir, "ui_btn.png"))

print("Assets generated.")

# ---------------------------------------------------------
# 2. GENERATE AUDIO (Sine waves)
# ---------------------------------------------------------
def generate_wav(path, freq_start, freq_end, duration, sample_rate=44100):
    num_samples = int(duration * sample_rate)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        for i in range(num_samples):
            t = float(i) / sample_rate
            # Linear frequency sweep
            freq = freq_start + (freq_end - freq_start) * (i / num_samples)
            value = int(32767.0 * 0.5 * math.sin(2.0 * math.pi * freq * t))
            w.writeframes(struct.pack('h', value))

generate_wav(os.path.join(assets_dir, "jump.wav"), 200, 600, 0.2)
generate_wav(os.path.join(assets_dir, "coin.wav"), 800, 1200, 0.1)
generate_wav(os.path.join(assets_dir, "hit.wav"), 100, 50, 0.3)
print("Audio generated.")

# ---------------------------------------------------------
# 3. GODOT CONFIG
# ---------------------------------------------------------
project_godot = """
; Engine configuration file.
[application]
config/name="Vector Godot Runner Advanced"
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

# ---------------------------------------------------------
# 4. SCRIPTS
# ---------------------------------------------------------
scripts = {
    "Player.gd": """extends CharacterBody2D

const RUN_SPEED = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY = 1600.0

var state = "run" # run, jump, fall, slide, stun
var stun_timer = 0.0

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
        
        # Handle sliding
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
                
        # Handle Jumping
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

    # Update visual frame based on state
    if state == "run":
        anim.region_rect.position.x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        anim.region_rect.position.x = 200
    elif state == "slide":
        anim.region_rect.position.x = 300
        
    move_and_slide()

func stun():
    if state != "stun":
        state = "stun"
        stun_timer = 1.0
        sfx_hit.play()
        # Visual feedback
        modulate = Color(1, 0.5, 0.5)
        await get_tree().create_timer(1.0).timeout
        modulate = Color(1, 1, 1)
""",
    
    "Chaser.gd": """extends CharacterBody2D

@export var player_path: NodePath
@onready var player = get_node(player_path)
const NORMAL_SPEED = 490.0
const CATCH_SPEED = 550.0
const GRAVITY = 1600.0

@onready var anim = $Sprite2D

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += GRAVITY * delta
        
    if player:
        # Accelerate if player is close or stunned
        var dist = player.global_position.x - global_position.x
        if dist < 400 or player.state == "stun":
            velocity.x = CATCH_SPEED
        else:
            velocity.x = NORMAL_SPEED
            
        # Jump logic (mirror player loosely or jump when stuck)
        if is_on_wall() and is_on_floor():
            velocity.y = -700.0
            
        # Catch logic
        if dist < 40:
            get_tree().reload_current_scene()
            
    # Animate
    if is_on_floor():
        anim.region_rect.position.x = (Engine.get_frames_drawn() / 10 % 2) * 100
    else:
        anim.region_rect.position.x = 200
            
    move_and_slide()
""",

    "LevelManager.gd": """extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var hud_danger = $CanvasLayer/HUD/Danger
@onready var sfx_coin = $SfxCoin

var distance = 0.0
var score = 0
var diamonds = 0
var chunk_x = 2000.0

# Preloaded assets for generation
var ground_tex = preload("res://assets/ground.png")
var obs_tall_tex = preload("res://assets/obs_tall.png")
var obs_low_tex = preload("res://assets/obs_low.png")
var obs_crate_tex = preload("res://assets/obs_crate.png")
var coin_tex = preload("res://assets/coin.png")

func _process(_delta):
    if player:
        camera.global_position.x = player.global_position.x + 300
        distance = player.global_position.x / 100.0
        hud_score.text = "Distance: %dm | Score: %d | Diamonds: %d" % [int(distance), score, diamonds]
        
        # Danger warning
        var dist_to_chaser = player.global_position.x - $Chaser.global_position.x
        hud_danger.visible = dist_to_chaser < 300
        
        # Procedural generation
        if camera.global_position.x + 1500 > chunk_x:
            spawn_chunk()

func spawn_chunk():
    var chunk = StaticBody2D.new()
    chunk.position = Vector2(chunk_x, randf_range(500, 650))
    add_child(chunk)
    
    # Ground visual
    var spr = Sprite2D.new()
    spr.texture = ground_tex
    spr.position = Vector2(500, 100) # Center of 1000x200
    spr.scale = Vector2(2.0, 1.0)
    chunk.add_child(spr)
    
    # Ground collision
    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(1000, 200)
    col.shape = shape
    col.position = Vector2(500, 100)
    chunk.add_child(col)
    
    # Spawn obstacles
    if randf() > 0.5:
        var type = randi() % 3
        var obs = Area2D.new()
        obs.position = Vector2(randf_range(200, 800), 0)
        
        var o_spr = Sprite2D.new()
        var o_col = CollisionShape2D.new()
        var o_shape = RectangleShape2D.new()
        
        if type == 0: # Tall barrier
            o_spr.texture = obs_tall_tex
            o_spr.position = Vector2(0, -60)
            o_shape.size = Vector2(30, 120)
        elif type == 1: # Low beam
            o_spr.texture = obs_low_tex
            o_spr.position = Vector2(0, -40)
            o_shape.size = Vector2(200, 80)
        else: # Crate
            o_spr.texture = obs_crate_tex
            o_spr.position = Vector2(0, -30)
            o_shape.size = Vector2(60, 60)
            
        o_col.shape = o_shape
        o_col.position = o_spr.position
        
        obs.add_child(o_spr)
        obs.add_child(o_col)
        # Connect signal
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        chunk.add_child(obs)
        
    # Spawn coins
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
        
    chunk_x += 1000 + randf_range(150, 300) # Add gap

func _on_obstacle_hit(body, obs_node):
    if body.name == "Player":
        body.stun()
        
func _on_coin_hit(body, coin_node):
    if body.name == "Player":
        score += 1
        sfx_coin.play()
        coin_node.queue_free()
"""
}
for name, content in scripts.items():
    with open(os.path.join(scripts_dir, name), "w") as f:
        f.write(content)

# ---------------------------------------------------------
# 5. GENERATE SCENES (.tscn)
# ---------------------------------------------------------
scenes = {
    "Main.tscn": """[gd_scene load_steps=9 format=3]
[ext_resource type="Script" path="res://scripts/LevelManager.gd" id="1_lvl"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="2_sky"]
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

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)

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
[node name="Danger" type="Label" parent="CanvasLayer/HUD"]
visible = false
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -300.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(1, 0, 0, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_font_sizes/font_size = 32
text = "!! CHASER CLOSE !!"

[node name="BtnJump" type="TouchScreenButton" parent="CanvasLayer/HUD"]
position = Vector2(0, 0)
scale = Vector2(6.4, 1.8)
action = "jump"

[node name="BtnSlide" type="TouchScreenButton" parent="CanvasLayer/HUD"]
position = Vector2(0, 360)
scale = Vector2(6.4, 1.8)
action = "slide"
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

    "Chaser.tscn": """[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(30, 80)

[node name="Chaser" type="CharacterBody2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 10)
shape = SubResource("RectangleShape2D_1")
"""
}

for name, content in scenes.items():
    with open(os.path.join(scenes_dir, name), "w") as f:
        f.write(content)

print("Advanced Godot project generated successfully!")
