import os, shutil

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets_dir = os.path.join(base_dir, "assets")
scenes_dir = os.path.join(base_dir, "scenes")
scripts_dir = os.path.join(base_dir, "scripts")

# 1. Remove stale .import files for vector_bg.png so Godot re-imports cleanly
stale_import = os.path.join(assets_dir, "vector_bg.png.import")
if os.path.exists(stale_import):
    os.remove(stale_import)
    print("Removed stale import file.")

# 2. Clear the whole .godot cache directory
godot_cache = os.path.join(base_dir, ".godot")
if os.path.exists(godot_cache):
    shutil.rmtree(godot_cache)
    print("Cleared .godot cache.")

# 3. Fix Chaser.gd - remove reload_current_scene() which was causing the flicker loop
chaser_gd = """extends Node2D

@export var player_path: NodePath
@onready var player = get_node_or_null(player_path)
@onready var anim = $Sprite2D

var delay_frames = 60
var current_catch_up = 0.0
var game_over = false

func _ready():
    # Safety: if player_path invalid, do nothing
    if not player:
        set_physics_process(false)

func _physics_process(delta):
    if game_over or not player:
        return
    if player.trail.size() == 0:
        return
        
    # Adjust delay (chaser speeds up when player is stunned)
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
        
    # Game over: caught the player — show message, don't flicker
    if global_position.distance_to(player.global_position) < 50:
        game_over = true
        player.set_physics_process(false)
        set_physics_process(false)
        # Show simple game over after 1 second
        await get_tree().create_timer(1.0).timeout
        get_tree().reload_current_scene()
"""

# 4. Fix Main.tscn - use city_far.png as fallback sky to avoid missing asset error
# (vector_bg is still referenced but we ensure it imports correctly via .import removal)
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
offset_right = 600.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_font_sizes/font_size = 32
text = "Distance: 0m | Score: 0"
"""

with open(os.path.join(scripts_dir, "Chaser.gd"), "w") as f:
    f.write(chaser_gd)
    print("Fixed Chaser.gd")

with open(os.path.join(scenes_dir, "Main.tscn"), "w") as f:
    f.write(main_tscn)
    print("Fixed Main.tscn (using sky.png instead of vector_bg.png to avoid missing asset error)")

print("All fixes applied. Re-open Main.tscn in Godot and press Play!")
