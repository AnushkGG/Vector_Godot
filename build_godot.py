import os
from PIL import Image, ImageDraw

def create_image(path, size, color, shape="rect", text=None):
    img = Image.new('RGBA', size, (0,0,0,0))
    draw = ImageDraw.Draw(img)
    if shape == "rect":
        draw.rectangle([0, 0, size[0], size[1]], fill=color)
    elif shape == "circle":
        draw.ellipse([0, 0, size[0], size[1]], fill=color)
    elif shape == "diamond":
        draw.polygon([(size[0]/2, 0), (size[0], size[1]/2), (size[0]/2, size[1]), (0, size[1]/2)], fill=color)
    
    if text:
        # Simple cross for player/chaser to indicate facing direction
        draw.line([size[0]*0.7, size[1]*0.2, size[0]*0.9, size[1]*0.2], fill="white", width=2)
    img.save(path)

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
os.makedirs(os.path.join(base_dir, "assets"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "scenes"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "scripts"), exist_ok=True)

# 1. GENERATE ASSETS
create_image(os.path.join(base_dir, "assets", "player.png"), (30, 70), "black", text="P")
create_image(os.path.join(base_dir, "assets", "chaser.png"), (35, 75), "#220000", text="C")
create_image(os.path.join(base_dir, "assets", "ground.png"), (500, 100), "black")
create_image(os.path.join(base_dir, "assets", "bg_city.png"), (1280, 720), "#444444")
create_image(os.path.join(base_dir, "assets", "coin.png"), (20, 20), "yellow", "circle")
create_image(os.path.join(base_dir, "assets", "diamond.png"), (24, 24), "cyan", "diamond")
create_image(os.path.join(base_dir, "assets", "obstacle.png"), (40, 40), "black", "circle")

# 2. PROJECT.GODOT
project_godot = """
; Engine configuration file.
[application]
config/name="Vector Godot Runner"
run/main_scene="res://scenes/Level1.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[input]
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
backflip={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194325,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
"""
with open(os.path.join(base_dir, "project.godot"), "w") as f:
    f.write(project_godot.strip())

# 3. SCRIPTS
scripts = {
    "Player.gd": """extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -600.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_running = false

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed("jump"):
        is_running = true
        if is_on_floor():
            velocity.y = JUMP_VELOCITY
            
    if Input.is_action_just_pressed("backflip") and is_on_floor():
        is_running = true
        velocity.y = JUMP_VELOCITY * 1.2
        # Backflip animation logic would go here

    if is_running:
        velocity.x = SPEED
    else:
        velocity.x = 0

    move_and_slide()
""",
    "Chaser.gd": """extends CharacterBody2D

@export var player_path: NodePath
@onready var player = get_node(player_path)
const SPEED = 420.0 # Slightly faster to catch up
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var active = false

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += gravity * delta
        
    if player and player.is_running:
        active = true
        
    if active:
        velocity.x = SPEED
        # Simple jump if stuck
        if is_on_wall() and is_on_floor():
            velocity.y = -600.0
    
    move_and_slide()
    
    # Catch logic
    if player and global_position.x >= player.global_position.x - 20:
        get_tree().reload_current_scene() # Game over placeholder
""",
    "Level1.gd": """extends Node2D

var coins = 0
var diamonds = 0
@onready var ui_label = $CanvasLayer/HUD/Label

func _ready():
    update_ui()

func add_coin():
    coins += 1
    update_ui()
    check_progression()

func add_diamond():
    diamonds += 1
    update_ui()
    check_progression()

func update_ui():
    ui_label.text = "Coins: %d/50 | Diamonds: %d/2" % [coins, diamonds]

func check_progression():
    if coins >= 50 and diamonds >= 2:
        ui_label.text = "LEVEL 2 READY!"
        get_tree().paused = true
"""
}
for name, content in scripts.items():
    with open(os.path.join(base_dir, "scripts", name), "w") as f:
        f.write(content)

# 4. SCENES
scenes = {
    "Player.tscn": """[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/Player.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/player.png" id="2_tex"]
[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(30, 70)
[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_scr")
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")
[node name="Camera2D" type="Camera2D" parent="."]
offset = Vector2(300, -100)
""",
    "Chaser.tscn": """[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/chaser.png" id="2_tex"]
[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(35, 75)
[node name="Chaser" type="CharacterBody2D"]
script = ExtResource("1_scr")
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")
""",
    "Coin.tscn": """[gd_scene load_steps=3 format=3]
[ext_resource type="Texture2D" path="res://assets/coin.png" id="1_tex"]
[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 10.0
[node name="Coin" type="Area2D"]
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("1_tex")
[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
""",
    "Level1.tscn": """[gd_scene load_steps=7 format=3]
[ext_resource type="Script" path="res://scripts/Level1.gd" id="1_scr"]
[ext_resource type="PackedScene" path="res://scenes/Player.tscn" id="2_plr"]
[ext_resource type="PackedScene" path="res://scenes/Chaser.tscn" id="3_chs"]
[ext_resource type="Texture2D" path="res://assets/bg_city.png" id="4_bg"]
[ext_resource type="Texture2D" path="res://assets/ground.png" id="5_grnd"]
[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(5000, 100)

[node name="Level1" type="Node2D"]
script = ExtResource("1_scr")

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]
[node name="ParallaxLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.2, 1)
motion_mirroring = Vector2(1280, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/ParallaxLayer"]
texture = ExtResource("4_bg")
centered = false

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(0, 600)
[node name="Sprite2D" type="Sprite2D" parent="Ground"]
position = Vector2(2500, 50)
scale = Vector2(10, 1)
texture = ExtResource("5_grnd")
[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
position = Vector2(2500, 50)
shape = SubResource("RectangleShape2D_1")

[node name="Player" parent="." instance=ExtResource("2_plr")]
position = Vector2(400, 500)

[node name="Chaser" parent="." instance=ExtResource("3_chs")]
position = Vector2(100, 500)
player_path = NodePath("../Player")

[node name="CanvasLayer" type="CanvasLayer" parent="."]
[node name="HUD" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
[node name="Label" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 20.0
offset_top = 20.0
offset_right = 300.0
offset_bottom = 60.0
theme_override_font_sizes/font_size = 32
text = "Press UP to start"
"""
}
for name, content in scenes.items():
    with open(os.path.join(base_dir, "scenes", name), "w") as f:
        f.write(content)

print("Godot project generated successfully!")
