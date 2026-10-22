import os
import math
import struct
import wave
from PIL import Image, ImageDraw

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets_dir = os.path.join(base_dir, "assets")
scenes_dir = os.path.join(base_dir, "scenes")
scripts_dir = os.path.join(base_dir, "scripts")

# -------------------------------------------------------
# FIX 1: Generate sky.png (beautiful sunset gradient)
# -------------------------------------------------------
img = Image.new('RGB', (1280, 720))
draw = ImageDraw.Draw(img)
top_color    = (255, 120, 60)   # warm orange
bottom_color = (80,  30, 100)   # deep purple
for y in range(720):
    r = int(top_color[0] + (bottom_color[0] - top_color[0]) * (y / 720))
    g = int(top_color[1] + (bottom_color[1] - top_color[1]) * (y / 720))
    b = int(top_color[2] + (bottom_color[2] - top_color[2]) * (y / 720))
    draw.line([(0, y), (1280, y)], fill=(r, g, b))
img.save(os.path.join(assets_dir, "sky.png"))
print("sky.png generated")

# -------------------------------------------------------
# FIX 2: Write Chaser.gd with proper game_over flag
# -------------------------------------------------------
chaser_gd = """extends Node2D

@export var player_path: NodePath

var player = null
var anim = null
var delay_frames = 60
var current_catch_up = 0.0
var game_over = false

func _ready():
    player = get_node_or_null(player_path)
    anim = get_node_or_null("Sprite2D")
    if not player:
        set_physics_process(false)

func _physics_process(delta):
    if game_over or not player:
        return
    if player.trail.size() == 0:
        return

    # Speed up when player stunned
    if player.state == "stun":
        delay_frames = max(10, delay_frames - 1)
    else:
        if delay_frames < 60:
            current_catch_up += delta
            if current_catch_up > 0.1:
                delay_frames += 1
                current_catch_up = 0.0

    var target_idx = player.trail.size() - delay_frames - 1
    if target_idx < 0:
        target_idx = 0

    var data = player.trail[target_idx]
    global_position = data["pos"]
    var p_state = data["state"]

    if anim:
        var rect_x = 0
        if p_state == "run" or p_state == "stun":
            rect_x = (Engine.get_frames_drawn() / 10 % 2) * 100
        elif p_state == "jump" or p_state == "fall":
            rect_x = 200
        elif p_state == "slide":
            rect_x = 300
        anim.region_rect = Rect2(rect_x, 0, 100, 100)

    # Catch player — stop loop, reload after 1 second
    if global_position.distance_to(player.global_position) < 50:
        game_over = true
        set_physics_process(false)
        if player.has_method("set_physics_process"):
            player.set_physics_process(false)
        await get_tree().create_timer(1.5).timeout
        get_tree().reload_current_scene()
"""
with open(os.path.join(scripts_dir, "Chaser.gd"), "w") as f:
    f.write(chaser_gd)
print("Chaser.gd fixed")

# -------------------------------------------------------
# FIX 3: Rewrite Chaser.tscn with correct format
# -------------------------------------------------------
chaser_tscn = """[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2_tex"]

[node name="Chaser" type="Node2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)
"""
with open(os.path.join(scenes_dir, "Chaser.tscn"), "w") as f:
    f.write(chaser_tscn)
print("Chaser.tscn fixed")

# -------------------------------------------------------
# FIX 4: Rewrite Main.tscn using ONLY existing assets
# -------------------------------------------------------
main_tscn = """[gd_scene load_steps=9 format=3]
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
position_smoothing_speed = 8.0

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
offset_right = 700.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_font_sizes/font_size = 32
text = "Distance: 0m | Score: 0"
"""
with open(os.path.join(scenes_dir, "Main.tscn"), "w") as f:
    f.write(main_tscn)
print("Main.tscn fixed")

print("\nAll fixes done! Reload in Godot and open Main.tscn.")
